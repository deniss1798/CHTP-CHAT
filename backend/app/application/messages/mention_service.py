import re

from sqlalchemy.orm import Session

from app.models.chat_member import ChatMember
from app.models.message_mention import MessageMention
from app.models.user import User

_MENTION_RE = re.compile(r"(?<![\w@])@([A-Za-z0-9_.\-]{2,32})")


def extract_mention_usernames(text: str) -> list[str]:
    if not text:
        return []
    seen: list[str] = []
    out: list[str] = []
    for match in _MENTION_RE.finditer(text):
        name = match.group(1).lower()
        if name in seen:
            continue
        seen.append(name)
        out.append(match.group(1))
    return out


def resolve_chat_mentions(
    db: Session,
    *,
    chat_id: int,
    text: str | None,
    explicit_user_ids: list[int] | None = None,
) -> list[int]:
    explicit = {int(x) for x in (explicit_user_ids or [])}
    raw_names = extract_mention_usernames(text or "")
    if not raw_names and not explicit:
        return []

    member_user_ids = {
        int(uid)
        for (uid,) in db.query(ChatMember.user_id).filter(
            ChatMember.chat_id == chat_id,
        ).all()
    }
    if not member_user_ids:
        return []

    by_username = {}
    if raw_names:
        rows = (
            db.query(User.id, User.username)
            .filter(User.username.in_(raw_names))
            .all()
        )
        by_username = {str(u.username).lower(): int(u.id) for u in rows}

    found: list[int] = []
    seen: set[int] = set()
    for name in raw_names:
        uid = by_username.get(name.lower())
        if uid is None:
            continue
        if uid not in member_user_ids:
            continue
        if uid in seen:
            continue
        seen.add(uid)
        found.append(uid)

    for uid in explicit:
        if uid in member_user_ids and uid not in seen:
            seen.add(uid)
            found.append(uid)

    return found


def replace_message_mentions(
    db: Session,
    *,
    message_id: int,
    user_ids: list[int],
) -> None:
    db.query(MessageMention).filter(
        MessageMention.message_id == message_id
    ).delete()
    for uid in user_ids:
        db.add(MessageMention(message_id=message_id, user_id=uid))


def load_message_mentions_map(
    db: Session,
    *,
    message_ids: list[int],
) -> dict[int, list[int]]:
    if not message_ids:
        return {}
    rows = (
        db.query(MessageMention.message_id, MessageMention.user_id)
        .filter(MessageMention.message_id.in_(message_ids))
        .order_by(MessageMention.id.asc())
        .all()
    )
    out: dict[int, list[int]] = {}
    for mid, uid in rows:
        out.setdefault(int(mid), []).append(int(uid))
    return out
