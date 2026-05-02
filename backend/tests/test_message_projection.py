from types import SimpleNamespace

from app.application.messages.message_projection import safe_message_type


def test_safe_message_type_defaults_empty_to_text() -> None:
    m = SimpleNamespace(message_type=None)
    assert safe_message_type(m) == "text"  # type: ignore[arg-type]


def test_safe_message_type_strips_blank_string() -> None:
    m = SimpleNamespace(message_type="   ")
    assert safe_message_type(m) == "text"  # type: ignore[arg-type]


def test_safe_message_type_passthrough() -> None:
    m = SimpleNamespace(message_type="image")
    assert safe_message_type(m) == "image"  # type: ignore[arg-type]
