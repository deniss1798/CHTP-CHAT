from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.application.messages.message_projection import (
    build_message_payload,
    message_to_response,
)
from app.application.messages.poll_service import serialize_poll
from app.application.realtime.chat_events import (
    publish_new_message,
    publish_poll_updated,
)
from app.domain.policies.chat_access import require_chat_member
from app.models.message import Message
from app.models.poll import Poll, PollOption, PollVote
from app.models.user import User
from app.repositories.messages_repository import MessagesRepository
from app.schemas.message_schema import MessageResponse, PollCreate, PollVoteRequest


def _validate_options(options: list[str]) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()
    for opt in options:
        s = (opt or "").strip()
        if not s:
            continue
        if len(s) > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Poll option is too long",
            )
        low = s.casefold()
        if low in seen:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Duplicate poll options are not allowed",
            )
        seen.add(low)
        cleaned.append(s)
    if len(cleaned) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Poll needs at least 2 options",
        )
    return cleaned


async def create_poll_message(
    db: Session,
    *,
    current_user: User,
    payload: PollCreate,
) -> MessageResponse:
    repo = MessagesRepository(db)
    require_chat_member(db, payload.chat_id, current_user)
    question = payload.question.strip()
    if not question:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Poll question is required",
        )
    options = _validate_options(payload.options)

    client_message_id = (
        payload.client_message_id.strip() if payload.client_message_id else None
    )
    if client_message_id:
        existing = repo.get_by_client_message_id(
            sender_id=current_user.id,
            client_message_id=client_message_id,
        )
        if existing is not None:
            return message_to_response(existing, db, viewer_user_id=current_user.id)

    new_message = Message(
        chat_id=payload.chat_id,
        sender_id=current_user.id,
        text=question,
        message_type="poll",
        client_message_id=client_message_id,
        is_updated=False,
    )
    repo.add(new_message)
    repo.commit_refresh(new_message)

    poll = Poll(
        message_id=new_message.id,
        question=question,
        allows_multiple=bool(payload.allows_multiple),
        is_anonymous=bool(payload.is_anonymous),
        is_closed=False,
    )
    db.add(poll)
    db.flush()
    for idx, text in enumerate(options):
        db.add(PollOption(poll_id=poll.id, position=idx, text=text))
    db.commit()
    db.refresh(new_message)

    await publish_new_message(
        new_message.chat_id,
        build_message_payload(new_message, db),
    )
    return message_to_response(new_message, db, viewer_user_id=current_user.id)


async def vote_in_poll(
    db: Session,
    *,
    current_user: User,
    message_id: int,
    payload: PollVoteRequest,
) -> MessageResponse:
    repo = MessagesRepository(db)
    message = repo.get_by_id(message_id)
    if not message or message.message_type != "poll":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Poll not found",
        )
    require_chat_member(db, message.chat_id, current_user)
    poll = db.query(Poll).filter(Poll.message_id == message_id).first()
    if poll is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Poll not found",
        )
    if poll.is_closed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Poll is closed",
        )

    option_ids = list({int(x) for x in payload.option_ids})
    if option_ids:
        valid = {
            int(opt_id)
            for (opt_id,) in db.query(PollOption.id)
            .filter(PollOption.poll_id == poll.id, PollOption.id.in_(option_ids))
            .all()
        }
        if len(valid) != len(option_ids):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unknown poll option",
            )
    if not poll.allows_multiple and len(option_ids) > 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Poll allows only one option",
        )

    db.query(PollVote).filter(
        PollVote.poll_id == poll.id,
        PollVote.user_id == current_user.id,
    ).delete()
    for opt_id in option_ids:
        db.add(
            PollVote(
                poll_id=poll.id,
                option_id=opt_id,
                user_id=current_user.id,
            )
        )
    db.commit()

    poll_state = serialize_poll(db, poll=poll, viewer_user_id=current_user.id)
    await publish_poll_updated(
        message.chat_id,
        message.id,
        poll_state.model_dump(mode="json"),
    )
    return message_to_response(message, db, viewer_user_id=current_user.id)


async def close_poll(
    db: Session,
    *,
    current_user: User,
    message_id: int,
) -> MessageResponse:
    repo = MessagesRepository(db)
    message = repo.get_by_id(message_id)
    if not message or message.message_type != "poll":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Poll not found",
        )
    require_chat_member(db, message.chat_id, current_user)
    if message.sender_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only poll author can close",
        )

    poll = db.query(Poll).filter(Poll.message_id == message_id).first()
    if poll is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Poll not found",
        )
    if not poll.is_closed:
        poll.is_closed = True
        db.commit()

    poll_state = serialize_poll(db, poll=poll, viewer_user_id=current_user.id)
    await publish_poll_updated(
        message.chat_id,
        message.id,
        poll_state.model_dump(mode="json"),
    )
    return message_to_response(message, db, viewer_user_id=current_user.id)
