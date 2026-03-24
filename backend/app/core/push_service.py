from firebase_admin import messaging
from sqlalchemy.orm import Session

from app.core.firebase_admin import get_firebase_app
from app.models.device_token import DeviceToken


def send_chat_message_push(
    db: Session,
    *,
    sender_name: str,
    chat_id: int,
    recipient_user_ids: list[int],
    message_text: str | None,
):
    get_firebase_app()

    tokens = (
        db.query(DeviceToken)
        .filter(
            DeviceToken.user_id.in_(recipient_user_ids),
            DeviceToken.is_active == True,
        )
        .all()
    )

    if not tokens:
        return

    body = (message_text or "Новое сообщение").strip()
    if len(body) > 120:
        body = body[:120]

    for item in tokens:
        try:
            msg = messaging.Message(
                token=item.token,
                notification=messaging.Notification(
                    title=sender_name,
                    body=body,
                ),
                data={
                    "type": "chat_message",
                    "chat_id": str(chat_id),
                },
                android=messaging.AndroidConfig(priority="high"),
            )
            messaging.send(msg)
        except Exception as e:
            print(f"Push send failed for token id={item.id}: {e}")