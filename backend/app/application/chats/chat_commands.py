import hashlib

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.application.chats.chat_queries import message_type_for_chat_list, unread_count_for_user
from app.application.messages.message_projection import DELETED_MESSAGE_TEXT
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.chat_schema import ChatCreate, ChatResponse


def _private_chat_pair(user_a: int, user_b: int) -> tuple[int, int]:
    return tuple(sorted((user_a, user_b)))


def _private_pair_key(user_a: int, user_b: int) -> str:
    pair = _private_chat_pair(user_a, user_b)
    return f"{pair[0]}:{pair[1]}"


def _private_chat_lock_key(user_a: int, user_b: int) -> int:
    pair = _private_chat_pair(user_a, user_b)
    digest = hashlib.blake2b(f"private-chat:{pair[0]}:{pair[1]}".encode(), digest_size=8)
    return int.from_bytes(digest.digest(), byteorder="big", signed=True)


def _lock_private_chat_pair(db: Session, user_a: int, user_b: int) -> None:
    if db.bind is None or db.bind.dialect.name != "postgresql":
        return

    db.execute(
        text("SELECT pg_advisory_xact_lock(:lock_key)"),
        {"lock_key": _private_chat_lock_key(user_a, user_b)},
    )


def _find_private_chat_between(db: Session, user_a: int, user_b: int) -> Chat | None:
    key = _private_pair_key(user_a, user_b)
    keyed = db.query(Chat).filter(Chat.private_pair_key == key).first()
    if keyed is not None:
        return keyed

    pair = set(_private_chat_pair(user_a, user_b))
    rows = (
        db.query(Chat)
        .join(ChatMember, ChatMember.chat_id == Chat.id)
        .filter(
            Chat.type == "private",
            ChatMember.user_id.in_(pair),
        )
        .group_by(Chat.id)
        .having(func.count(func.distinct(ChatMember.user_id)) == 2)
        .all()
    )

    for chat in rows:
        member_ids = {
            row.user_id
            for row in db.query(ChatMember.user_id)
            .filter(ChatMember.chat_id == chat.id)
            .all()
        }
        if member_ids == pair:
            return chat

    return None


def _private_chat_response(
    db: Session,
    chat: Chat,
    current_user_id: int,
    other_user_id: int,
) -> ChatResponse:
    other_user = db.query(User).filter(User.id == other_user_id).first()
    last_message = (
        db.query(Message)
        .filter(Message.chat_id == chat.id)
        .order_by(Message.created_at.desc(), Message.id.desc())
        .first()
    )
    member_row = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat.id,
            ChatMember.user_id == current_user_id,
        )
        .first()
    )
    my_lr = (member_row.last_read_message_id or 0) if member_row else 0

    return ChatResponse(
        id=chat.id,
        type=chat.type,
        title=other_user.username if other_user else chat.title,
        avatar_url=other_user.avatar_url if other_user else chat.avatar_url,
        created_by=chat.created_by,
        last_message=(
            DELETED_MESSAGE_TEXT
            if last_message and bool(getattr(last_message, "is_deleted", False))
            else (last_message.text if last_message else None)
        ),
        last_message_type=message_type_for_chat_list(last_message),
        last_message_at=last_message.created_at if last_message else None,
        last_message_sender_id=last_message.sender_id if last_message else None,
        last_message_sender_name=None,
        last_message_id=last_message.id if last_message else None,
        my_last_read_message_id=my_lr,
        unread_count=unread_count_for_user(db, chat.id, current_user_id),
        peer_last_seen_at=other_user.last_seen_at if other_user else None,
    )


def create_chat(db: Session, current_user: User, payload: ChatCreate) -> ChatResponse:
    if payload.type not in ("private", "group"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid chat type",
        )

    member_ids = set(payload.member_ids)
    member_ids.add(current_user.id)

    if payload.type == "private":
        other_ids = [user_id for user_id in member_ids if user_id != current_user.id]
        if len(other_ids) != 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Private chat must contain exactly one other participant",
            )

        other_user_id = other_ids[0]
        private_pair_key = _private_pair_key(current_user.id, other_user_id)

        existing_chat = _find_private_chat_between(db, current_user.id, other_user_id)
        if existing_chat:
            return _private_chat_response(db, existing_chat, current_user.id, other_user_id)

        _lock_private_chat_pair(db, current_user.id, other_user_id)
        existing_chat = _find_private_chat_between(db, current_user.id, other_user_id)
        if existing_chat:
            return _private_chat_response(db, existing_chat, current_user.id, other_user_id)

    users = db.query(User).filter(User.id.in_(member_ids)).all()
    found_ids = {user.id for user in users}
    missing_ids = member_ids - found_ids

    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Users not found: {sorted(missing_ids)}",
        )

    title = payload.title
    avatar_url = None

    if payload.type == "private":
        other_user = next((user for user in users if user.id != current_user.id), None)
        title = other_user.username if other_user else "Private chat"
        avatar_url = other_user.avatar_url if other_user else None
    else:
        private_pair_key = None
        if not title or not title.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Group chat title is required",
            )
        title = title.strip()

    chat = Chat(
        type=payload.type,
        title=title,
        avatar_url=avatar_url,
        created_by=current_user.id,
        private_pair_key=private_pair_key,
    )
    db.add(chat)
    db.flush()

    for user_id in member_ids:
        role = "owner" if user_id == current_user.id else "member"
        db.add(
            ChatMember(
                chat_id=chat.id,
                user_id=user_id,
                role=role,
            )
        )

    try:
        db.commit()
        db.refresh(chat)
    except IntegrityError:
        db.rollback()
        if payload.type == "private":
            existing_chat = _find_private_chat_between(
                db,
                current_user.id,
                other_user_id,
            )
            if existing_chat:
                return _private_chat_response(
                    db,
                    existing_chat,
                    current_user.id,
                    other_user_id,
                )
        raise

    peer_last_seen_at = None
    if payload.type == "private":
        other_u = next((u for u in users if u.id != current_user.id), None)
        if other_u:
            peer_last_seen_at = other_u.last_seen_at

    return ChatResponse(
        id=chat.id,
        type=chat.type,
        title=chat.title,
        avatar_url=chat.avatar_url,
        created_by=chat.created_by,
        last_message=None,
        last_message_type=None,
        last_message_at=None,
        last_message_sender_id=None,
        last_message_sender_name=None,
        last_message_id=None,
        my_last_read_message_id=0,
        unread_count=0,
        peer_last_seen_at=peer_last_seen_at,
    )
