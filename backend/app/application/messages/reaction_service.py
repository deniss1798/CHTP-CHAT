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
        users = acc[r.message_id].setdefault(r.emoji, [])
        users.append(r.user_id)

    out: dict[int, list[ReactionGroup]] = {}
    for mid, emojis in acc.items():
        groups: list[ReactionGroup] = []
        for emoji in sorted(emojis.keys()):
            user_ids = sorted(set(emojis[emoji]))
            groups.append(
                ReactionGroup(
                    emoji=emoji,
                    count=len(user_ids),
                    reacted_by_me=viewer_user_id in user_ids,
                    reactor_user_ids=user_ids,
                )
            )
        out[mid] = groups
    return out
