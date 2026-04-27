from app.core.security import create_access_token, create_ws_token, decode_ws_or_access_token


def test_ws_token_has_ws_type_and_subject() -> None:
    token = create_ws_token(user_id=42, expires_seconds=60)

    payload = decode_ws_or_access_token(token)

    assert payload is not None
    assert payload["sub"] == "42"
    assert payload["typ"] == "ws"


def test_ws_decoder_accepts_legacy_access_token_for_compatibility() -> None:
    token = create_access_token({"sub": "42"})

    payload = decode_ws_or_access_token(token)

    assert payload is not None
    assert payload["sub"] == "42"


def test_ws_decoder_rejects_unexpected_token_type() -> None:
    token = create_access_token({"sub": "42", "typ": "refresh"})

    assert decode_ws_or_access_token(token) is None
