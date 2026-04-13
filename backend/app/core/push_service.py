from firebase_admin import messaging
from sqlalchemy.orm import Session

from app.core.firebase_admin import get_firebase_app
from app.models.device_token import DeviceToken


def _is_invalid_fcm_token_error(exc: BaseException) -> bool:
    s = str(exc).lower()
    needles = (
        "registration-token-not-registered",
        "requested entity was not found",
        "invalid-registration-token",
        "not a valid fcm registration token",
        "unregistered",
    )
    return any(n in s for n in needles)


def send_chat_message_push(
    db: Session,
    *,
    sender_name: str,
    chat_id: int,
    recipient_user_ids: list[int],
    message_text: str | None,
):
    try:
        get_firebase_app()
    except RuntimeError as e:
        print(f"[push] Firebase not configured, skip: {e}")
        return

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
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default"),
                    ),
                ),
            )
            messaging.send(msg)
        except Exception as e:
            print(f"Push send failed for token id={item.id}: {e}")
            if _is_invalid_fcm_token_error(e):
                item.is_active = False
                db.commit()
