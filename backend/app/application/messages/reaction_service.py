from collections import defaultdict

from sqlalchemy.orm import Session

from app.models.message_reaction import MessageReaction
from app.schemas.message_schema import ReactionGroup


def reaction_groups_for_messages(
    db: Session,
    message_ids: list[int],
    viewer_user_id: int,
) -> dict[int, list[ReactionGroup]]:
    if not message_ids:
        return {}
    rows = (
        db.query(MessageReaction)
        .filter(MessageReaction.message_id.in_(message_ids))
        .all()
    )
    acc: dict[int, dict[str, list[int]]] = defaultdict(dict)
    for r in rows:
        bucket = acc[r.message_id].setdefault(r.emoji, [0, 0])
        bucket[0] += 1
        if r.user_id == viewer_user_id:
            bucket[1] = 1

    out: dict[int, list[ReactionGroup]] = {}
    for mid, emojis in acc.items():
        out[mid] = [
            ReactionGroup(
                emoji=emoji,
                count=data[0],
                reacted_by_me=bool(data[1]),
            )
            for emoji, data in sorted(emojis.items())
        ]
    return out
