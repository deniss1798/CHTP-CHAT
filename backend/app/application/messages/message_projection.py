from collections.abc import Callable

from sqlalchemy.orm import Session

from app.application.media.constants import PRIVATE_MEDIA_MESSAGE_TYPES
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.application.messages.reaction_service import reaction_groups_for_messages
from app.core.config import get_settings
from app.schemas.message_schema import MessageReplyPreview, MessageResponse, ReactionGroup
from app.infrastructure.storage.s3_storage import S3StorageService, is_private_s3_ready

DELETED_MESSAGE_TEXT = "Сообщение удалено"


def make_s3_getter(
    storage: S3StorageService | None = None,
) -> Callable[[], S3StorageService]:
    if storage is not None:
        return lambda: storage
    holder: list[S3StorageService | None] = [None]

    def get() -> S3StorageService:
        if holder[0] is None:
            holder[0] = S3StorageService()
        return holder[0]

    return get


def load_reply_parent(db: Session, reply_to_message_id: int | None) -> Message | None:
    if not reply_to_message_id:
        return None
    return db.query(Message).filter(Message.id == reply_to_message_id).first()


def safe_message_text(message: Message) -> str:
    if bool(getattr(message, "is_deleted", False)):
        return DELETED_MESSAGE_TEXT
    t = message.text
    return "" if t is None else str(t)


def safe_message_type(message: Message) -> str:
    if bool(getattr(message, "is_deleted", False)):
        return "deleted"
    mt = message.message_type
    if mt is None or (isinstance(mt, str) and not mt.strip()):
        return "text"
    return str(mt)


def reply_preview_for_parent(
    parent: Message,
    get_storage: Callable[[], S3StorageService],
) -> MessageReplyPreview:
    media_url = parent.media_url
    ptype = safe_message_type(parent)
    if bool(getattr(parent, "is_deleted", False)):
        media_url = None
    if (
        is_private_s3_ready()
        and ptype in PRIVATE_MEDIA_MESSAGE_TYPES
        and parent.media_key
    ):
        media_url = get_storage().generate_private_file_url(
            object_key=parent.media_key,
            expires_in=get_settings().private_media_url_ttl_seconds,
        )
    return MessageReplyPreview(
        id=parent.id,
        sender_id=parent.sender_id,
        text=safe_message_text(parent),
        message_type=ptype,
        media_url=media_url,
    )


def compute_delivery_status(
    db: Session,
    chat_id: int,
    message: Message,
    viewer_user_id: int,
) -> str | None:
    if message.sender_id != viewer_user_id:
        return None
    members = (
        db.query(ChatMember)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )
    others = [m for m in members if m.user_id != message.sender_id]
    if not others:
        return None
    for m in others:
        lr = m.last_read_message_id or 0
        if lr < message.id:
            return "sent"
    return "read"


def compute_delivery_statuses(
    db: Session,
    *,
    chat_id: int,
    messages: list[Message],
    viewer_user_id: int,
) -> dict[int, str | None]:
    own_messages = [message for message in messages if message.sender_id == viewer_user_id]
    if not own_messages:
        return {}

    members = db.query(ChatMember).filter(ChatMember.chat_id == chat_id).all()
    others = [member for member in members if member.user_id != viewer_user_id]
    if not others:
        return {message.id: None for message in own_messages}

    out: dict[int, str | None] = {}
    for message in own_messages:
        out[message.id] = (
            "read"
            if all((member.last_read_message_id or 0) >= message.id for member in others)
            else "sent"
        )
    return out


def message_to_response(
    message: Message,
    db: Session,
    storage: S3StorageService | None = None,
    viewer_user_id: int | None = None,
) -> MessageResponse:
    get_storage = make_s3_getter(storage)

    reply_preview: MessageReplyPreview | None = None
    if message.reply_to_message_id:
        parent = load_reply_parent(db, message.reply_to_message_id)
        if parent:
            reply_preview = reply_preview_for_parent(parent, get_storage)

    mtype_single = safe_message_type(message)
    media_url = message.media_url
    if bool(getattr(message, "is_deleted", False)):
        media_url = None
    if (
        is_private_s3_ready()
        and mtype_single in PRIVATE_MEDIA_MESSAGE_TYPES
        and message.media_key
    ):
        media_url = get_storage().generate_private_file_url(
            object_key=message.media_key,
            expires_in=get_settings().private_media_url_ttl_seconds,
        )

    delivery_status = None
    if viewer_user_id is not None:
        delivery_status = compute_delivery_status(
            db, message.chat_id, message, viewer_user_id
        )

    rlist: list[ReactionGroup] = []
    if viewer_user_id is not None:
        rmap = reaction_groups_for_messages(db, [message.id], viewer_user_id)
        rlist = rmap.get(message.id, [])

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=safe_message_text(message),
        message_type=mtype_single,
        client_message_id=message.client_message_id,
        media_key=None,
        media_url=media_url,
        media_mime_type=None if bool(getattr(message, "is_deleted", False)) else message.media_mime_type,
        media_size=None if bool(getattr(message, "is_deleted", False)) else message.media_size,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=bool(message.is_updated) if message.is_updated is not None else False,
        is_deleted=bool(getattr(message, "is_deleted", False)),
        reply_to_message_id=message.reply_to_message_id,
        reply_to=reply_preview,
        forwarded_from_user_id=message.forwarded_from_user_id,
        delivery_status=delivery_status,
        reactions=rlist,
    )


def message_to_response_batched(
    message: Message,
    parents_by_id: dict[int, Message],
    get_storage: Callable[[], S3StorageService],
    db: Session,
    viewer_user_id: int,
    reactions: list[ReactionGroup] | None = None,
    delivery_status: str | None = None,
) -> MessageResponse:
    reply_preview: MessageReplyPreview | None = None
    if message.reply_to_message_id:
        parent = parents_by_id.get(message.reply_to_message_id)
        if parent:
            reply_preview = reply_preview_for_parent(parent, get_storage)

    media_url = message.media_url
    mtype = safe_message_type(message)
    if bool(getattr(message, "is_deleted", False)):
        media_url = None
    if (
        is_private_s3_ready()
        and mtype in PRIVATE_MEDIA_MESSAGE_TYPES
        and message.media_key
    ):
        media_url = get_storage().generate_private_file_url(
            object_key=message.media_key,
            expires_in=get_settings().private_media_url_ttl_seconds,
        )

    if delivery_status is None:
        delivery_status = compute_delivery_status(
            db, message.chat_id, message, viewer_user_id
        )

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=safe_message_text(message),
        message_type=mtype,
        client_message_id=message.client_message_id,
        media_key=None,
        media_url=media_url,
        media_mime_type=None if bool(getattr(message, "is_deleted", False)) else message.media_mime_type,
        media_size=None if bool(getattr(message, "is_deleted", False)) else message.media_size,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=bool(message.is_updated) if message.is_updated is not None else False,
        is_deleted=bool(getattr(message, "is_deleted", False)),
        reply_to_message_id=message.reply_to_message_id,
        reply_to=reply_preview,
        forwarded_from_user_id=message.forwarded_from_user_id,
        delivery_status=delivery_status,
        reactions=reactions or [],
    )


def build_message_payload(
    message: Message, db: Session, storage: S3StorageService | None = None
) -> dict:
    get_storage = make_s3_getter(storage)

    reply_to_dict = None
    if message.reply_to_message_id:
        parent = load_reply_parent(db, message.reply_to_message_id)
        if parent:
            reply_to_dict = reply_preview_for_parent(parent, get_storage).model_dump()

    media_url = message.media_url
    mtype_payload = safe_message_type(message)
    is_deleted = bool(getattr(message, "is_deleted", False))
    if is_deleted:
        media_url = None
    if (
        is_private_s3_ready()
        and mtype_payload in PRIVATE_MEDIA_MESSAGE_TYPES
        and message.media_key
    ):
        media_url = get_storage().generate_private_file_url(
            object_key=message.media_key,
            expires_in=get_settings().private_media_url_ttl_seconds,
        )

    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "text": safe_message_text(message),
        "message_type": mtype_payload,
        "client_message_id": message.client_message_id,
        "media_key": None,
        "media_url": media_url,
        "media_mime_type": None if is_deleted else message.media_mime_type,
        "media_size": None if is_deleted else message.media_size,
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "updated_at": message.updated_at.isoformat() if message.updated_at else None,
        "is_updated": message.is_updated,
        "is_deleted": is_deleted,
        "reply_to_message_id": message.reply_to_message_id,
        "reply_to": reply_to_dict,
        "forwarded_from_user_id": message.forwarded_from_user_id,
        "reactions": [],
    }


def apply_private_media_urls(messages: list[Message]) -> list[Message]:
    if not is_private_s3_ready():
        return messages

    get_storage = make_s3_getter()

    for message in messages:
        mtype = safe_message_type(message)
        if not bool(getattr(message, "is_deleted", False)) and mtype in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
            message.media_url = get_storage().generate_private_file_url(
                object_key=message.media_key,
                expires_in=get_settings().private_media_url_ttl_seconds,
            )

    return messages


def apply_private_media_urls_map(messages: list[Message]) -> None:
    if not is_private_s3_ready():
        return

    get_storage = make_s3_getter()

    for message in messages:
        mtype = safe_message_type(message)
        if not bool(getattr(message, "is_deleted", False)) and mtype in PRIVATE_MEDIA_MESSAGE_TYPES and message.media_key:
            message.media_url = get_storage().generate_private_file_url(
                object_key=message.media_key,
                expires_in=get_settings().private_media_url_ttl_seconds,
            )
