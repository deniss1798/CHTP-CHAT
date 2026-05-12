from sqlalchemy.orm import Session

from app.models.poll import Poll, PollOption, PollVote
from app.schemas.message_schema import PollOptionResponse, PollResponse


def serialize_poll(
    db: Session,
    *,
    poll: Poll,
    viewer_user_id: int | None,
) -> PollResponse:
    options = (
        db.query(PollOption)
        .filter(PollOption.poll_id == poll.id)
        .order_by(PollOption.position.asc(), PollOption.id.asc())
        .all()
    )
    votes = (
        db.query(PollVote.option_id, PollVote.user_id)
        .filter(PollVote.poll_id == poll.id)
        .all()
    )

    voters_by_option: dict[int, list[int]] = {}
    voted_by_me: set[int] = set()
    for row in votes:
        voters_by_option.setdefault(int(row.option_id), []).append(int(row.user_id))
        if viewer_user_id is not None and int(row.user_id) == int(viewer_user_id):
            voted_by_me.add(int(row.option_id))

    expose_voters = not bool(poll.is_anonymous)

    items: list[PollOptionResponse] = []
    total_votes = 0
    for option in options:
        voter_ids = voters_by_option.get(int(option.id), [])
        items.append(
            PollOptionResponse(
                id=int(option.id),
                position=int(option.position),
                text=str(option.text),
                votes=len(voter_ids),
                voted_by_me=int(option.id) in voted_by_me,
                voter_user_ids=voter_ids if expose_voters else [],
            )
        )
        total_votes += len(voter_ids)

    return PollResponse(
        id=int(poll.id),
        message_id=int(poll.message_id),
        question=str(poll.question),
        allows_multiple=bool(poll.allows_multiple),
        is_anonymous=bool(poll.is_anonymous),
        is_closed=bool(poll.is_closed),
        total_votes=total_votes,
        options=items,
    )
