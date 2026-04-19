from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.application.media.constants import ALLOWED_IMAGE_TYPES, MAX_AVATAR_SIZE
from app.application.chats.chat_commands import create_chat as execute_create_chat
from app.application.chats.chat_listing import list_my_chats
from app.application.chats.chat_queries import build_chat_detail_response
from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.domain.policies.chat_access import require_chat_member
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
    ChatUpdate,
    MarkChatReadRequest,
    MemberReadState,
)
from app.infrastructure.storage.s3_storage import S3StorageService, is_s3_configured

router = APIRouter(prefix="/chats", tags=["Chats"])


@router.get("/", response_model=list[ChatResponse])
def get_my_chats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_my_chats(db, current_user)


@router.post("/", response_model=ChatResponse)
def create_chat(
    payload: ChatCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return execute_create_chat(db, current_user, payload)


@router.get("/{chat_id}", response_model=ChatDetailResponse)
def get_chat_detail(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return build_chat_detail_response(db, chat_id, current_user)


@router.get("/{chat_id}/members", response_model=list[ChatMemberResponse])
def get_chat_members(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_chat_member(db, chat_id, current_user)

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
    require_chat_member(db, chat_id, current_user)

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
    member = require_chat_member(db, chat_id, current_user)

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

    require_chat_member(db, chat_id, current_user)

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

    return build_chat_detail_response(db, chat_id, current_user)


@router.patch("/{chat_id}", response_model=ChatDetailResponse)
def update_group_chat(
    chat_id: int,
    payload: ChatUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(Chat).filter(Chat.id == chat_id).first()

    if not chat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Chat not found",
        )

    require_chat_member(db, chat_id, current_user)

    if chat.type != "group":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only group chats can be renamed",
        )

    chat.title = payload.title.strip()
    db.add(chat)
    db.commit()
    db.refresh(chat)

    return build_chat_detail_response(db, chat_id, current_user)


@router.post("/{chat_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
def leave_group_chat(
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

    if chat.type != "group":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only group chats can be left",
        )

    membership = require_chat_member(db, chat_id, current_user)

    uid = current_user.id

    if chat.created_by == uid:
        others = (
            db.query(ChatMember)
            .filter(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id != uid,
            )
            .order_by(ChatMember.user_id.asc())
            .all()
        )
        if others:
            next_owner = others[0]
            chat.created_by = next_owner.user_id
            next_owner.role = "owner"
            db.add(chat)
            db.add(next_owner)

    db.delete(membership)
    db.flush()

    remaining = (
        db.query(ChatMember).filter(ChatMember.chat_id == chat_id).count()
    )
    if remaining == 0:
        db.query(Message).filter(Message.chat_id == chat_id).delete()
        db.delete(chat)

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{chat_id}/members/{member_user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_group_member(
    chat_id: int,
    member_user_id: int,
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
            detail="Only for group chats",
        )

    require_chat_member(db, chat_id, current_user)

    if chat.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only group creator can remove members",
        )

    if member_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use leave endpoint to exit the group",
        )

    target = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == member_user_id,
        )
        .first()
    )

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User is not a member",
        )

    was_creator_target = chat.created_by == member_user_id
    db.delete(target)
    db.flush()

    if was_creator_target:
        nxt = (
            db.query(ChatMember)
            .filter(ChatMember.chat_id == chat_id)
            .order_by(ChatMember.user_id.asc())
            .first()
        )
        if nxt:
            chat.created_by = nxt.user_id
            nxt.role = "owner"
            db.add(chat)
            db.add(nxt)

    remaining = (
        db.query(ChatMember).filter(ChatMember.chat_id == chat_id).count()
    )
    if remaining == 0:
        db.query(Message).filter(Message.chat_id == chat_id).delete()
        db.delete(chat)

    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


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

    require_chat_member(db, chat_id, current_user)

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