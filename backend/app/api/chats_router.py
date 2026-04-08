from datetime import datetime

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.models.chat import Chat
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.core.ws_manager import manager
from app.schemas.chat_schema import (
    ChatCreate,
    ChatDetailResponse,
    ChatMemberAddRequest,
    ChatMemberResponse,
    ChatResponse,
    MarkChatReadRequest,
    MemberReadState,
    UserShort,
)
from app.services.s3_storage import S3StorageService

router = APIRouter(prefix="/chats", tags=["Chats"])

def _unread_count_for_user(db: Session, chat_id: int, user_id: int) -> int:
    member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == user_id,
        )
        .first()
    )
    if not member:
        return 0
    last_read = member.last_read_message_id or 0
    return (
        db.query(Message)
        .filter(
            Message.chat_id == chat_id,
            Message.sender_id != user_id,
            Message.id > last_read,
        )
        .count()
    )


ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

MAX_AVATAR_SIZE = 5 * 1024 * 1024


@router.get("/", response_model=list[ChatResponse])
def get_my_chats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chats = (
        db.query(Chat)
        .join(ChatMember, ChatMember.chat_id == Chat.id)
        .filter(ChatMember.user_id == current_user.id)
        .order_by(Chat.id.desc())
        .all()
    )

    result = []

    for chat in chats:
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

        result.append(
            ChatResponse(
                id=chat.id,
                type=chat.type,
                title=chat_title,
                avatar_url=chat_avatar_url,
                created_by=chat.created_by,
                last_message=last_message.text if last_message else None,
                last_message_at=last_message.created_at if last_message else None,
                last_message_sender_id=last_message.sender_id if last_message else None,
                unread_count=_unread_count_for_user(db, chat.id, current_user.id),
                peer_last_seen_at=peer_last_seen_at,
            )
        )

    result.sort(
        key=lambda item: item.last_message_at or datetime.min,
        reverse=True,
    )

    return result


@router.post("/", response_model=ChatResponse)
def create_chat(
    payload: ChatCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.type not in ("private", "group"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid chat type",
        )

    member_ids = set(payload.member_ids)
    member_ids.add(current_user.id)

    if payload.type == "private":
        other_ids = [user_id for user_id in member_ids if user_id != current_user.id]
        if len(other_ids) != 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Private chat must contain exactly one other participant",
            )

        other_user_id = other_ids[0]

        private_chats = (
            db.query(Chat)
            .join(ChatMember, ChatMember.chat_id == Chat.id)
            .filter(
                Chat.type == "private",
                ChatMember.user_id == current_user.id,
            )
            .all()
        )

        for chat in private_chats:
            existing_member_ids = {
                row.user_id
                for row in db.query(ChatMember.user_id)
                .filter(ChatMember.chat_id == chat.id)
                .all()
            }

            if existing_member_ids == {current_user.id, other_user_id}:
                other_user = db.query(User).filter(User.id == other_user_id).first()

                last_message = (
                    db.query(Message)
                    .filter(Message.chat_id == chat.id)
                    .order_by(Message.created_at.desc(), Message.id.desc())
                    .first()
                )

                return ChatResponse(
                    id=chat.id,
                    type=chat.type,
                    title=other_user.username if other_user else chat.title,
                    avatar_url=other_user.avatar_url if other_user else chat.avatar_url,
                    created_by=chat.created_by,
                    last_message=last_message.text if last_message else None,
                    last_message_at=last_message.created_at if last_message else None,
                    last_message_sender_id=last_message.sender_id if last_message else None,
                    unread_count=0,
                    peer_last_seen_at=other_user.last_seen_at if other_user else None,
                )

    users = db.query(User).filter(User.id.in_(member_ids)).all()
    found_ids = {user.id for user in users}
    missing_ids = member_ids - found_ids

    if missing_ids:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Users not found: {sorted(missing_ids)}",
        )

    title = payload.title
    avatar_url = None

    if payload.type == "private":
        other_user = next((user for user in users if user.id != current_user.id), None)
        title = other_user.username if other_user else "Private chat"
        avatar_url = other_user.avatar_url if other_user else None
    else:
        if not title or not title.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Group chat title is required",
            )
        title = title.strip()

    chat = Chat(
        type=payload.type,
        title=title,
        avatar_url=avatar_url,
        created_by=current_user.id,
    )
    db.add(chat)
    db.flush()

    for user_id in member_ids:
        role = "owner" if user_id == current_user.id else "member"
        db.add(
            ChatMember(
                chat_id=chat.id,
                user_id=user_id,
                role=role,
            )
        )

    db.commit()
    db.refresh(chat)

    peer_last_seen_at = None
    if payload.type == "private":
        other_u = next((u for u in users if u.id != current_user.id), None)
        if other_u:
            peer_last_seen_at = other_u.last_seen_at

    return ChatResponse(
        id=chat.id,
        type=chat.type,
        title=chat.title,
        avatar_url=chat.avatar_url,
        created_by=chat.created_by,
        last_message=None,
        last_message_at=None,
        last_message_sender_id=None,
        unread_count=0,
        peer_last_seen_at=peer_last_seen_at,
    )


@router.get("/{chat_id}", response_model=ChatDetailResponse)
def get_chat_detail(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    chat_member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not chat_member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    users = (
        db.query(User)
        .join(ChatMember, ChatMember.user_id == User.id)
        .filter(ChatMember.chat_id == chat_id)
        .order_by(User.username.asc())
        .all()
    )

    members = [
        UserShort(
            id=user.id,
            username=user.username,
            email=user.email,
            avatar_url=user.avatar_url,
            last_seen_at=user.last_seen_at,
        )
        for user in users
    ]

    chat_title = chat.title
    chat_avatar_url = chat.avatar_url

    if chat.type == "private":
        other_user = next((user for user in users if user.id != current_user.id), None)
        if other_user:
            chat_title = other_user.username
            chat_avatar_url = other_user.avatar_url

    return ChatDetailResponse(
        id=chat.id,
        type=chat.type,
        title=chat_title,
        avatar_url=chat_avatar_url,
        created_by=chat.created_by,
        members=members,
    )


@router.get("/{chat_id}/members", response_model=list[ChatMemberResponse])
def get_chat_members(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat_member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not chat_member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    members = (
        db.query(User, ChatMember.role)
        .join(ChatMember, ChatMember.user_id == User.id)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )

    return [
        ChatMemberResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            avatar_url=user.avatar_url,
            role=role,
            last_seen_at=user.last_seen_at,
        )
        for user, role in members
    ]


@router.get("/{chat_id}/read-state", response_model=list[MemberReadState])
def get_chat_read_state(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    rows = (
        db.query(ChatMember.user_id, ChatMember.last_read_message_id)
        .filter(ChatMember.chat_id == chat_id)
        .all()
    )

    return [
        MemberReadState(user_id=uid, last_read_message_id=lrid)
        for uid, lrid in rows
    ]


@router.post("/{chat_id}/read")
async def mark_chat_read(
    chat_id: int,
    body: MarkChatReadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    msg = (
        db.query(Message)
        .filter(Message.id == body.message_id, Message.chat_id == chat_id)
        .first()
    )

    if not msg:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    prev = member.last_read_message_id or 0
    if body.message_id > prev:
        member.last_read_message_id = body.message_id
        db.commit()
        db.refresh(member)

        await manager.broadcast(
            chat_id,
            {
                "type": "read_receipt",
                "chat_id": chat_id,
                "user_id": current_user.id,
                "last_read_message_id": member.last_read_message_id,
            },
        )

    return {
        "detail": "ok",
        "last_read_message_id": member.last_read_message_id,
    }


@router.patch("/{chat_id}/avatar", response_model=ChatDetailResponse)
async def upload_chat_avatar(
    chat_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    if chat.type != "group":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Avatar can be changed only for group chats",
        )

    membership = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    if membership.role != "owner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group owner can change avatar",
        )

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
    old_avatar_url = chat.avatar_url

    new_avatar_url = storage.upload_public_avatar(
        content=content,
        folder="avatars/chats",
        owner_id=chat.id,
        extension=extension,
        content_type=file.content_type,
    )

    chat.avatar_url = new_avatar_url

    db.add(chat)
    db.commit()
    db.refresh(chat)

    storage.delete_public_object_by_url(old_avatar_url)

    users = (
        db.query(User)
        .join(ChatMember, ChatMember.user_id == User.id)
        .filter(ChatMember.chat_id == chat_id)
        .order_by(User.username.asc())
        .all()
    )

    members = [
        UserShort(
            id=user.id,
            username=user.username,
            email=user.email,
            avatar_url=user.avatar_url,
            last_seen_at=user.last_seen_at,
        )
        for user in users
    ]

    return ChatDetailResponse(
        id=chat.id,
        type=chat.type,
        title=chat.title,
        avatar_url=chat.avatar_url,
        created_by=chat.created_by,
        members=members,
    )


@router.post("/{chat_id}/members", response_model=ChatMemberResponse)
def add_chat_member(
    chat_id: int,
    payload: ChatMemberAddRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    requester_membership = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not requester_membership:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    if chat.type != "group":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can add members only to group chats",
        )

    if payload.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already in this chat",
        )

    user_to_add = db.query(User).filter(User.id == payload.user_id).first()

    if not user_to_add:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    existing_member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == payload.user_id,
        )
        .first()
    )

    if existing_member:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a member of this chat",
        )

    new_member = ChatMember(
        chat_id=chat_id,
        user_id=payload.user_id,
        role="member",
    )

    db.add(new_member)
    db.commit()

    return ChatMemberResponse(
        id=user_to_add.id,
        username=user_to_add.username,
        email=user_to_add.email,
        avatar_url=user_to_add.avatar_url,
        role="member",
        last_seen_at=user_to_add.last_seen_at,
    )