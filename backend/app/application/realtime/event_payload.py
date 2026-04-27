from datetime import datetime, timezone
from uuid import uuid4


def realtime_event(payload: dict) -> dict:
    """Attach stable metadata to every realtime event delivered over WebSocket."""
    event = dict(payload)
    event.setdefault("event_id", uuid4().hex)
    event.setdefault("occurred_at", datetime.now(timezone.utc).isoformat())
    return event
