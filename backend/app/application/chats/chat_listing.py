import base64
import json
from datetime import datetime

from sqlalchemy import and_, desc, func, or_
from sqlalchemy.orm import Session

from app.application.chats.chat_queries import message_type_for_chat_list, unread_count_for_user
from app.application.messages.message_projection import DELETED_MESSAGE_TEXT
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.chat_schema import ChatListPage, ChatResponse

_EPOCH = datetime(1970, 1, 1)


def _encode_chat_cursor(last_message_at: datetime | None, chat_id: int) -> str:
    payload = {
        "a": last_message_at.isoformat() if last_message_at else None,
        "c": chat_id,
    }
    raw = json.dumps(payload, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).decode()


def _decode_chat_cursor(cursor: str) -> tuple[datetime | None, int]:
    raw = json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
    la = datetime.fromisoformat(raw["a"]) if raw.get("a") else None
    return la, int(raw["c"])


def _build_chat_response(
    db: Session,
    chat: Chat,
    current_user: User,
) -> ChatResponse:
    chat_title = chat.title
    chat_avatar_url = chat.avatar_url

    users = (
        db.query(User)
        .join(ChatMember, ChatMember.user_id == User.id)
        .filter(ChatMember.chat_id == chat.id)
        .order_by(User.username.asc())
        .all()
    )

    peer_last_seen_at = None
    if chat.type == "private":
        other_user = next((user for user in users if user.id != current_user.id), None)
        if other_user:
            chat_title = other_user.username
            chat_avatar_url = other_user.avatar_url
            peer_last_seen_at = other_user.last_seen_at

    last_message = (
        db.query(Message)
        .filter(Message.chat_id == chat.id)
        .order_by(Message.created_at.desc(), Message.id.desc())
        .first()
    )

    last_message_sender_name: str | None = None
    if last_message and last_message.sender_id is not None:
        s_user = next(
            (u for u in users if u.id == int(last_message.sender_id)),
            None,
        )
        if s_user and str(s_user.username or "").strip():
            last_message_sender_name = str(s_user.username).strip()

    membership = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat.id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )
    my_last_read = (membership.last_read_message_id or 0) if membership else 0

    return ChatResponse(
        id=chat.id,
        type=chat.type,
        title=chat_title,
        avatar_url=chat_avatar_url,
        created_by=chat.created_by,
        last_message=(
            DELETED_MESSAGE_TEXT
            if last_message and bool(getattr(last_message, "is_deleted", False))
            else (last_message.text if last_message else None)
        ),
        last_message_type=message_type_for_chat_list(last_message),
        last_message_at=last_message.created_at if last_message else None,
        last_message_sender_id=last_message.sender_id if last_message else None,
        last_message_sender_name=last_message_sender_name,
        last_message_id=last_message.id if last_message else None,
        my_last_read_message_id=my_last_read,
        unread_count=unread_count_for_user(db, chat.id, current_user.id),
        peer_last_seen_at=peer_last_seen_at,
    )


def list_my_chats(db: Session, current_user: User) -> list[ChatResponse]:
    """Полный список (для обратной совместимости внутри сервисов)."""
    page = list_my_chats_page(db, current_user, limit=10_000, cursor=None)
    return page.chats


def list_my_chats_page(
    db: Session,
    current_user: User,
    *,
    limit: int,
    cursor: str | None,
) -> ChatListPage:
    """Список чатов по активности (последнее сообщение), курсорная пагинация."""
    lim = max(1, min(limit, 200))

    last_sub = (
        db.query(
            Message.chat_id.label("chat_id"),
            func.max(Message.created_at).label("last_at"),
        )
        .group_by(Message.chat_id)
        .subquery()
    )

    sort_col = func.coalesce(last_sub.c.last_at, _EPOCH)

    q = (
        db.query(Chat, last_sub.c.last_at)
        .join(ChatMember, ChatMember.chat_id == Chat.id)
        .outerjoin(last_sub, last_sub.c.chat_id == Chat.id)
        .filter(ChatMember.user_id == current_user.id)
    )

    if cursor:
        cursor_la, cursor_cid = _decode_chat_cursor(cursor)
        cursor_sort = cursor_la or _EPOCH
        q = q.filter(
            or_(
                sort_col < cursor_sort,
                and_(sort_col == cursor_sort, Chat.id < cursor_cid),
            )
        )

    rows = (
        q.order_by(desc(sort_col), desc(Chat.id)).limit(lim + 1).all()
    )

    has_more = len(rows) > lim
    page_rows = rows[:lim]

    chats: list[ChatResponse] = []
    for chat, last_at in page_rows:
        chats.append(_build_chat_response(db, chat, current_user))

    next_cursor: str | None = None
    if has_more and page_rows:
        last_chat, last_la = page_rows[-1]
        next_cursor = _encode_chat_cursor(last_la, last_chat.id)

    return ChatListPage(chats=chats, has_more=has_more, next_cursor=next_cursor)
