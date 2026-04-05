from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.user_schema import UserResponse
from app.services.s3_storage import S3StorageService

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


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.get("/", response_model=list[UserResponse])
def search_users(
    q: str = Query("", min_length=0, max_length=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(User)

    if q.strip():
        query = query.filter(User.username.ilike(f"%{q.strip()}%"))

    users = (
        query.filter(User.id != current_user.id)
        .order_by(User.username.asc())
        .limit(20)
        .all()
    )

    return users