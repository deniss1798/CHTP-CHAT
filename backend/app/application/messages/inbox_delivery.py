from sqlalchemy.orm import Session

from app.core.push_service import build_inbox_new_message_event
from app.core.realtime_bus import publish_inbox_event
from app.core.ws_manager import inbox_manager


async def notify_inbox_new_message(
    db: Session,
    *,
    chat_id: int,
    sender_name: str,
    preview: str,
    recipient_user_ids: list[int],
) -> None:
    if not recipient_user_ids:
        return
    for uid in recipient_user_ids:
        payload = build_inbox_new_message_event(
            db,
            chat_id=chat_id,
            recipient_user_id=uid,
            sender_name=sender_name,
            preview=preview,
        )
        await inbox_manager.send_json(uid, payload)
        await publish_inbox_event(uid, payload)
