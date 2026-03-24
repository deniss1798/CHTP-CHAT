from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.user_schema import UserResponse

router = APIRouter(prefix="/users", tags=["Users"])


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