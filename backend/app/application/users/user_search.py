import base64
import json

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.user_schema import UserResponse, UserSearchPage


def _encode_user_cursor(username: str, user_id: int) -> str:
    raw = json.dumps(
        {"u": username, "i": int(user_id)},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(raw).decode()


def _decode_user_cursor(cursor: str) -> tuple[str, int]:
    raw = json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
    return str(raw["u"]), int(raw["i"])


def search_users_page(
    db: Session,
    *,
    current_user: User,
    q: str,
    limit: int,
    cursor: str | None,
) -> UserSearchPage:
    raw = q.strip()
    if len(raw) < 2:
        return UserSearchPage(users=[], has_more=False, next_cursor=None)

    lim = max(1, min(limit, 50))
    qy = (
        db.query(User)
        .filter(User.username.ilike(f"%{raw}%"))
        .filter(User.id != current_user.id)
    )

    if cursor:
        cu, ci = _decode_user_cursor(cursor)
        qy = qy.filter(
            or_(
                User.username > cu,
                and_(User.username == cu, User.id > ci),
            )
        )

    rows = qy.order_by(User.username.asc(), User.id.asc()).limit(lim + 1).all()
    has_more = len(rows) > lim
    page_rows = rows[:lim]
    next_cursor: str | None = None
    if has_more and page_rows:
        last = page_rows[-1]
        next_cursor = _encode_user_cursor(last.username, int(last.id))

    users = [UserResponse.model_validate(u) for u in page_rows]
    return UserSearchPage(
        users=users,
        has_more=has_more,
        next_cursor=next_cursor,
    )
