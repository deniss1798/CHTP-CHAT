from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.device_token import DeviceToken
from app.models.message import Message
from app.models.user import User
from app.application.users.user_search import search_users_page
from app.schemas.user_schema import UserPublicProfile, UserResponse, UserSearchPage
from app.infrastructure.storage.s3_storage import S3StorageService, is_s3_configured

router = APIRouter(prefix="/users", tags=["Users"])

ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_AVATAR_SIZE = 5 * 1024 * 1024  # 5 MB


@router.patch("/me/avatar", response_model=UserResponse)
async def upload_my_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not file.content_type or file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG and WEBP images are allowed",
        )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file",
        )

    if len(content) > MAX_AVATAR_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File is too large. Max size is 5 MB",
        )

    if not is_s3_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Public media storage (S3) is not fully configured",
        )

    storage = S3StorageService()

    extension = ALLOWED_IMAGE_TYPES[file.content_type]
    old_avatar_url = current_user.avatar_url

    new_avatar_url = storage.upload_public_avatar(
        content=content,
        folder="avatars/users",
        owner_id=current_user.id,
        extension=extension,
        content_type=file.content_type,
    )

    current_user.avatar_url = new_avatar_url

    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    storage.delete_public_object_by_url(old_avatar_url)

    return current_user


@router.post("/me/presence", status_code=status.HTTP_204_NO_CONTENT)
def post_my_presence(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Клиент вызывает периодически (и при открытии приложения), чтобы другие видели «в сети»."""
    current_user.last_seen_at = datetime.now(timezone.utc)
    db.add(current_user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.get("/", response_model=UserSearchPage)
def search_users(
    q: str = Query("", max_length=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = Query(20, ge=1, le=50),
    cursor: str | None = Query(
        default=None,
        description="Курсор следующей страницы (next_cursor с предыдущего ответа)",
    ),
):
    return search_users_page(
        db,
        current_user=current_user,
        q=q,
        limit=limit,
        cursor=cursor,
    )


@router.get("/{user_id}", response_model=UserPublicProfile)
def get_user_public_profile(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserPublicProfile(
        id=user.id,
        username=user.username,
        avatar_url=user.avatar_url,
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    uid = current_user.id

    db.query(DeviceToken).filter(DeviceToken.user_id == uid).delete(
        synchronize_session=False,
    )
    db.query(Message).filter(Message.sender_id == uid).delete(
        synchronize_session=False,
    )

    while True:
        m = (
            db.query(ChatMember)
            .filter(ChatMember.user_id == uid)
            .first()
        )
        if not m:
            break
        cid = m.chat_id
        chat = db.query(Chat).filter(Chat.id == cid).first()
        if not chat:
            db.delete(m)
            continue
        if chat.type == "private":
            db.query(ChatMember).filter(ChatMember.chat_id == cid).delete(
                synchronize_session=False,
            )
            db.query(Message).filter(Message.chat_id == cid).delete(
                synchronize_session=False,
            )
            db.delete(chat)
        else:
            if chat.created_by == uid:
                others = (
                    db.query(ChatMember)
                    .filter(
                        ChatMember.chat_id == cid,
                        ChatMember.user_id != uid,
                    )
                    .order_by(ChatMember.user_id.asc())
                    .all()
                )
                if others:
                    nxt = others[0]
                    chat.created_by = nxt.user_id
                    nxt.role = "owner"
                    db.add(chat)
                    db.add(nxt)
            db.delete(m)
            db.flush()
            remaining = (
                db.query(ChatMember)
                .filter(ChatMember.chat_id == cid)
                .count()
            )
            if remaining == 0:
                db.query(Message).filter(Message.chat_id == cid).delete(
                    synchronize_session=False,
                )
                db.delete(chat)

    for c in db.query(Chat).filter(Chat.created_by == uid).all():
        c.created_by = None
        db.add(c)

    db.query(User).filter(User.id == uid).delete(synchronize_session=False)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)