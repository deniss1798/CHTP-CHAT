from dataclasses import dataclass

from firebase_admin import messaging
from sqlalchemy.orm import Session

from app.core.firebase_admin import get_firebase_app
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.device_token import DeviceToken
from app.models.user import User


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


@dataclass(frozen=True)
class _PushAvatarContext:
    """Для группы одна ссылка; для private — аватар собеседника по user_id получателя."""

    default_url: str | None
    per_recipient: dict[int, str | None] | None


def _build_push_avatar_context(db: Session, chat_id: int) -> _PushAvatarContext | None:
    chat = db.query(Chat).filter(Chat.id == chat_id).first()
    if not chat:
        return None
    if chat.type == "private":
        members = (
            db.query(User)
            .join(ChatMember, ChatMember.user_id == User.id)
            .filter(ChatMember.chat_id == chat_id)
            .order_by(User.id.asc())
            .all()
        )
        if len(members) == 2:
            a, b = members[0], members[1]
            return _PushAvatarContext(
                default_url=None,
                per_recipient={
                    a.id: b.avatar_url,
                    b.id: a.avatar_url,
                },
            )
        return _PushAvatarContext(default_url=chat.avatar_url, per_recipient=None)
    return _PushAvatarContext(default_url=chat.avatar_url, per_recipient=None)


def _avatar_url_for_token(
    ctx: _PushAvatarContext,
    recipient_user_id: int,
) -> str | None:
    if ctx.per_recipient is not None:
        return ctx.per_recipient.get(recipient_user_id)
    return ctx.default_url


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

    avatar_ctx = _build_push_avatar_context(db, chat_id)

    body = (message_text or "Новое сообщение").strip()
    if len(body) > 120:
        body = body[:120]

    for item in tokens:
        try:
            avatar_url: str | None = None
            if avatar_ctx is not None:
                raw = _avatar_url_for_token(avatar_ctx, item.user_id)
                if raw and str(raw).strip():
                    avatar_url = str(raw).strip()

            data: dict[str, str] = {
                "type": "chat_message",
                "chat_id": str(chat_id),
            }
            if avatar_url:
                data["chat_avatar_url"] = avatar_url

            android_cfg = messaging.AndroidConfig(priority="high")
            if avatar_url:
                android_cfg = messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(image=avatar_url),
                )

            if avatar_url:
                apns_cfg = messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="default",
                            mutable_content=True,
                        ),
                    ),
                    fcm_options=messaging.APNSFCMOptions(image=avatar_url),
                )
            else:
                apns_cfg = messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound="default"),
                    ),
                )

            msg = messaging.Message(
                token=item.token,
                notification=messaging.Notification(
                    title=sender_name,
                    body=body,
                ),
                data=data,
                android=android_cfg,
                apns=apns_cfg,
            )
            messaging.send(msg)
        except Exception as e:
            print(f"Push send failed for token id={item.id}: {e}")
            if _is_invalid_fcm_token_error(e):
                item.is_active = False
                db.commit()
