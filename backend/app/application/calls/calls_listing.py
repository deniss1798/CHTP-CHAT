import base64
import json
from datetime import datetime

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.domain.policies.chat_access import require_chat_member
from app.models.call import Call
from app.models.chat_member import ChatMember
from app.models.user import User
from app.schemas.call_schema import CallListPage, CallResponse


def _encode_call_cursor(started_at: datetime, call_id: int) -> str:
    raw = json.dumps(
        {"s": started_at.isoformat(), "i": int(call_id)},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(raw).decode()


def _decode_call_cursor(cursor: str) -> tuple[datetime, int]:
    raw = json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
    return datetime.fromisoformat(str(raw["s"])), int(raw["i"])


def list_calls_page(
    db: Session,
    *,
    current_user: User,
    chat_id: int | None,
    limit: int,
    cursor: str | None,
) -> CallListPage:
    lim = max(1, min(limit, 200))
    if chat_id is not None:
        require_chat_member(db, int(chat_id), current_user)
        qy = db.query(Call).filter(Call.chat_id == int(chat_id))
    else:
        qy = (
            db.query(Call)
            .join(
                ChatMember,
                and_(
                    ChatMember.chat_id == Call.chat_id,
                    ChatMember.user_id == current_user.id,
                ),
            )
        )

    if cursor:
        cs, ci = _decode_call_cursor(cursor)
        qy = qy.filter(
            or_(
                Call.started_at < cs,
                and_(Call.started_at == cs, Call.id < ci),
            )
        )

    rows = qy.order_by(Call.started_at.desc(), Call.id.desc()).limit(lim + 1).all()
    has_more = len(rows) > lim
    page_rows = rows[:lim]
    next_cursor: str | None = None
    if has_more and page_rows:
        last = page_rows[-1]
        next_cursor = _encode_call_cursor(last.started_at, int(last.id))

    calls = [CallResponse.model_validate(c) for c in page_rows]
    return CallListPage(calls=calls, has_more=has_more, next_cursor=next_cursor)
