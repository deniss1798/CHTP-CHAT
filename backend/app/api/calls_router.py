from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.application.calls.calls_listing import list_calls_page
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.call_schema import CallListPage

router = APIRouter(prefix="/calls", tags=["Calls"])


@router.get("", response_model=CallListPage)
def list_calls(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    chat_id: int | None = Query(
        default=None,
        description="Опционально ограничить историю одним чатом (только если вы участник)",
    ),
    limit: int = Query(50, ge=1, le=200),
    cursor: str | None = Query(
        default=None,
        description="Курсор следующей страницы (next_cursor с предыдущего ответа)",
    ),
):
    return list_calls_page(
        db,
        current_user=current_user,
        chat_id=chat_id,
        limit=limit,
        cursor=cursor,
    )
