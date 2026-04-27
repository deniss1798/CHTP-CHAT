import base64
import json
from datetime import datetime

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.device_token import DeviceListPage, DeviceTokenResponse


def _encode_device_cursor(updated_at: datetime, device_id: int) -> str:
    u = updated_at.isoformat()
    raw = json.dumps(
        {"u": u, "i": int(device_id)},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(raw).decode()


def _decode_device_cursor(cursor: str) -> tuple[datetime, int]:
    raw = json.loads(base64.urlsafe_b64decode(cursor.encode()).decode())
    u = raw["u"]
    dt = datetime.fromisoformat(str(u))
    return dt, int(raw["i"])


def list_my_devices_page(
    db: Session,
    *,
    current_user: User,
    limit: int,
    cursor: str | None,
) -> DeviceListPage:
    lim = max(1, min(limit, 100))
    qy = db.query(DeviceToken).filter(DeviceToken.user_id == current_user.id)
    if cursor:
        cu, ci = _decode_device_cursor(cursor)
        qy = qy.filter(
            or_(
                DeviceToken.updated_at < cu,
                and_(DeviceToken.updated_at == cu, DeviceToken.id < ci),
            )
        )
    rows = (
        qy.order_by(DeviceToken.updated_at.desc(), DeviceToken.id.desc())
        .limit(lim + 1)
        .all()
    )
    has_more = len(rows) > lim
    page_rows = rows[:lim]
    next_cursor: str | None = None
    if has_more and page_rows:
        last = page_rows[-1]
        next_cursor = _encode_device_cursor(last.updated_at, int(last.id))

    devices = [DeviceTokenResponse.model_validate(d) for d in page_rows]
    return DeviceListPage(
        devices=devices,
        has_more=has_more,
        next_cursor=next_cursor,
    )
