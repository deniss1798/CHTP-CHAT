from __future__ import annotations

from pydantic import BaseModel, Field


class IceServerEntry(BaseModel):
    """Один элемент для RTCPeerConnection.iceServers (WebRTC)."""

    urls: str | list[str]
    username: str | None = None
    credential: str | None = None


class WebRtcIceResponse(BaseModel):
    ice_servers: list[IceServerEntry]
    ttl_seconds: int = Field(ge=300, le=86400)
    expires_at: int = Field(
        description="Unix time окончания действия TURN-username; при только STUN — условный срок обновления списка",
    )
