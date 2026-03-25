from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.core.ws_manager import manager
from app.db.database import get_db
from app.models.chat_member import ChatMember
from app.models.message import Message
from app.models.user import User
from app.schemas.message_schema import MessageCreate, MessageResponse, MessageUpdate
from datetime import datetime
from app.core.push_service import send_chat_message_push



router = APIRouter(prefix="/messages", tags=["Messages"])

@router.post("/", response_model=MessageResponse)
async def send_message(
    message: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = (
        db.query(ChatMember)
        .filter(
            ChatMember.chat_id == message.chat_id,
            ChatMember.user_id == current_user.id,
        )
        .first()
    )

    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this chat",
        )

    new_message = Message(
        chat_id=message.chat_id,
        sender_id=current_user.id,
        text=message.text,
        is_updated=False,
    )

    db.add(new_message)
    db.commit()
    db.refresh(new_message)

    await manager.broadcast(
        message.chat_id,
        {
            "type": "new_message",
            "message": {
                "id": new_message.id,
                "chat_id": new_message.chat_id,
                "sender_id": new_message.sender_id,
                "text": new_message.text,
                "created_at": new_message.created_at.isoformat()
                if new_message.created_at
                else None,
                "updated_at": new_message.updated_at.isoformat()
                if new_message.updated_at
                else None,
                "is_updated": new_message.is_updated,
            },
        },
    )

    recipient_user_ids = [
        row.user_id
        for row in db.query(ChatMember)
        .filter(ChatMember.chat_id == new_message.chat_id)
        .all()
        if row.user_id != current_user.id
    ]

    sender_name = current_user.username

    try:
        send_chat_message_push(
            db=db,
            chat_id=new_message.chat_id,
            sender_name=sender_name,
            recipient_user_ids=recipient_user_ids,
            message_text=new_message.text,
        )
    except Exception as e:
        print(f"Push sending skipped: {e}")

    return new_message

    return MessageResponse(
        id=new_message.id,
        chat_id=new_message.chat_id,
        sender_id=new_message.sender_id,
        text=new_message.text,
        created_at=new_message.created_at,
        updated_at=new_message.updated_at,
        is_updated=new_message.is_updated,
    )


    
@router.patch("/{message_id}", response_model=MessageResponse)
async def update_message(
    message_id: int,
    message_data: MessageUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = (
        db.query(Message)
        .filter(Message.id == message_id)
        .first()
    )

    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can edit only your own messages",
        )

    message.text = message_data.text
    message.updated_at = datetime.utcnow()
    message.is_updated = True

    db.commit()
    db.refresh(message)

    await manager.broadcast(
        message.chat_id,
        {
            "event": "message_updated",
            "id": message.id,
            "chat_id": message.chat_id,
            "sender_id": message.sender_id,
            "text": message.text,
            "created_at": str(message.created_at),
            "updated_at": str(message.updated_at),
            "is_updated": message.is_updated,
        },
    )

    return MessageResponse(
        id=message.id,
        chat_id=message.chat_id,
        sender_id=message.sender_id,
        text=message.text,
        created_at=message.created_at,
        updated_at=message.updated_at,
        is_updated=message.is_updated,
    )

@router.delete("/{message_id}")
async def delete_message(
    message_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = (
        db.query(Message)
        .filter(Message.id == message_id)
        .first()
    )

    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )

    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can delete only your own messages",
        )

    chat_id = message.chat_id

    db.delete(message)
    db.commit()

    await manager.broadcast(
        chat_id,
        {
            "event": "message_deleted",
            "id": message_id,
            "chat_id": chat_id,
        },
    )

    return {"detail": "Message deleted"}    

@router.get("/{chat_id}")
def get_chat_messages(
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

    messages = (
        db.query(Message)
        .filter(Message.chat_id == chat_id)
        .order_by(Message.created_at.asc())
        .all()
    )

    return [
        {
            "id": message.id,
            "chat_id": message.chat_id,
            "sender_id": message.sender_id,
            "text": message.text,
            "created_at": message.created_at,
            "updated_at": message.updated_at,
            "is_updated": message.is_updated,
        }
        for message in messages
    ]