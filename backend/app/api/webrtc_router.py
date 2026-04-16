from __future__ import annotations

import logging
import time

from fastapi import APIRouter, Depends

from app.core.config import get_settings
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.webrtc_schema import IceServerEntry, WebRtcIceResponse
from app.services.turn_credentials import build_turn_rest_username_and_credential

router = APIRouter(prefix="/webrtc", tags=["WebRTC"])
logger = logging.getLogger(__name__)


def _parse_stun_urls(raw: str) -> list[IceServerEntry]:
    urls = [u.strip() for u in raw.split(",") if u.strip()]
    return [IceServerEntry(urls=u) for u in urls]


def _turn_urls_for_host(host: str, udp_port: int, tls_port: int | None) -> list[str]:
    h = host.strip()
    out = [
        f"turn:{h}:{udp_port}?transport=udp",
        f"turn:{h}:{udp_port}?transport=tcp",
    ]
    if tls_port is not None and tls_port > 0:
        out.append(f"turns:{h}:{tls_port}?transport=tcp")
    return out


@router.get("/ice", response_model=WebRtcIceResponse)
def get_webrtc_ice_config(current_user: User = Depends(get_current_user)) -> WebRtcIceResponse:
    """
    Выдаёт iceServers для WebRTC: публичные STUN + при настройке — TURN с краткоживущим секретом.
    Требует Bearer JWT (не анонимный open relay через API).
    """
    settings = get_settings()
    fallback = _parse_stun_urls(settings.webrtc_fallback_stun_urls)

    secret = (settings.turn_static_auth_secret or "").strip()
    host = (settings.turn_server_host or "").strip()
    ttl = settings.turn_credential_ttl_seconds
    ttl = max(300, min(ttl, 86400))

    if not secret or not host:
        if secret and not host:
            logger.warning(
                "TURN_STATIC_AUTH_SECRET задан без TURN_SERVER_HOST — TURN отключён",
            )
        now = int(time.time())
        return WebRtcIceResponse(
            ice_servers=fallback,
            ttl_seconds=ttl,
            expires_at=now + ttl,
        )

    username, credential, expiry = build_turn_rest_username_and_credential(
        shared_secret=secret,
        opaque_user_suffix=str(current_user.id),
        ttl_seconds=ttl,
    )

    stun_same = f"stun:{host}:{settings.turn_udp_port}"
    turn_urls = _turn_urls_for_host(host, settings.turn_udp_port, settings.turn_tls_port)

    ice_servers: list[IceServerEntry] = [
        IceServerEntry(urls=stun_same),
        *fallback,
        IceServerEntry(
            urls=turn_urls,
            username=username,
            credential=credential,
        ),
    ]

    return WebRtcIceResponse(
        ice_servers=ice_servers,
        ttl_seconds=ttl,
        expires_at=expiry,
    )
