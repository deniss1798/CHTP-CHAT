from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.application.chats.chat_commands import create_chat
from app.application.chats.chat_listing import list_my_chats_page
from app.application.chats.chat_queries import build_chat_detail_response
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.chat_schema import ChatCreate, ChatDetailResponse, ChatListPage, ChatResponse

router = APIRouter()


@router.get("/", response_model=ChatListPage)
def get_my_chats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = Query(default=50, ge=1, le=200),
    cursor: str | None = Query(
        default=None,
        description="Курсор следующей страницы (next_cursor с предыдущего ответа)",
    ),
):
    return list_my_chats_page(db, current_user, limit=limit, cursor=cursor)


@router.post("/", response_model=ChatResponse)
def create_chat_endpoint(
    payload: ChatCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_chat(db, current_user, payload)


@router.get("/{chat_id}", response_model=ChatDetailResponse)
def get_chat_detail(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return build_chat_detail_response(db, chat_id, current_user)
