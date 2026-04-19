import base64
import hashlib
import hmac

from app.infrastructure.turn.turn_credentials import build_turn_rest_username_and_credential


def test_turn_rest_hmac_matches_manual() -> None:
    secret = "test-secret-32-chars-minimum!!"
    username, credential, expiry = build_turn_rest_username_and_credential(
        shared_secret=secret,
        opaque_user_suffix="42",
        ttl_seconds=3600,
    )
    assert username.endswith(":42")
    expected = base64.b64encode(
        hmac.new(
            secret.encode("utf-8"),
            username.encode("utf-8"),
            hashlib.sha1,
        ).digest(),
    ).decode("ascii")
    assert credential == expected
    assert expiry > 0
