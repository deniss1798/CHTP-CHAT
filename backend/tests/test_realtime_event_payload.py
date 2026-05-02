from datetime import datetime

from app.application.realtime.event_payload import realtime_event


def test_realtime_event_adds_stable_metadata():
    payload = realtime_event({"type": "typing", "chat_id": 1})

    assert payload["type"] == "typing"
    assert payload["chat_id"] == 1
    assert isinstance(payload["event_id"], str)
    assert payload["event_id"]
    assert datetime.fromisoformat(payload["occurred_at"])


def test_realtime_event_preserves_existing_metadata():
    payload = realtime_event(
        {
            "type": "new_message",
            "event_id": "fixed",
            "occurred_at": "2026-01-01T00:00:00+00:00",
        }
    )

    assert payload["event_id"] == "fixed"
    assert payload["occurred_at"] == "2026-01-01T00:00:00+00:00"
