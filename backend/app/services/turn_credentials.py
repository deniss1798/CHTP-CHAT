"""
Временные учётные данные TURN по схеме coturn «TURN REST API» (совместимо с use-auth-secret).

Формат (как в coturn / WebRTC samples):
  username = "<unix_expiry>:<opaque_id>"
  credential = base64( HMAC-SHA1(secret, username) )

На стороне coturn в turnserver.conf должны быть:
  use-auth-secret
  static-auth-secret=<тот же секрет, что TURN_STATIC_AUTH_SECRET на API>
  realm=<домен или имя сервера>

Диапазон relay-портов и firewall — только в конфиге coturn (min-port/max-port), не в этом коде.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import time


def build_turn_rest_username_and_credential(
    *,
    shared_secret: str,
    opaque_user_suffix: str,
    ttl_seconds: int,
) -> tuple[str, str, int]:
    """
    Возвращает (username, credential, expiry_unix).

    opaque_user_suffix — обычно id пользователя из JWT; попадает в username до двоеточия
    после timestamp (для корреляции в логах coturn, не для аутентификации по отдельному паролю).
    """
    now = int(time.time())
    ttl = max(300, min(ttl_seconds, 86400))
    expiry = now + ttl
    username = f"{expiry}:{opaque_user_suffix}"
    digest = hmac.new(
        shared_secret.encode("utf-8"),
        username.encode("utf-8"),
        hashlib.sha1,
    ).digest()
    credential = base64.b64encode(digest).decode("ascii")
    return username, credential, expiry
