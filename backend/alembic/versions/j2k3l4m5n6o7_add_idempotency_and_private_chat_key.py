"""add message idempotency and private chat pair key

Revision ID: j2k3l4m5n6o7
Revises: i9j0k1l2m3n4, g7h8i9j0k1l2
Create Date: 2026-04-29

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "j2k3l4m5n6o7"
down_revision: Union[str, Sequence[str], None] = (
    "i9j0k1l2m3n4",
    "g7h8i9j0k1l2",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "messages",
        sa.Column("client_message_id", sa.String(length=128), nullable=True),
    )
    op.create_unique_constraint(
        "uq_messages_sender_client_message_id",
        "messages",
        ["sender_id", "client_message_id"],
    )

    op.add_column(
        "chats",
        sa.Column("private_pair_key", sa.String(length=64), nullable=True),
    )
    conn = op.get_bind()
    dialect = conn.dialect.name
    if dialect == "postgresql":
        conn.execute(sa.text("""
            UPDATE chats c
            SET private_pair_key = pairs.pair_key
            FROM (
                SELECT
                    cm.chat_id,
                    min(cm.user_id)::text || ':' || max(cm.user_id)::text AS pair_key
                FROM chat_members cm
                JOIN chats ch ON ch.id = cm.chat_id
                WHERE ch.type = 'private'
                GROUP BY cm.chat_id
                HAVING count(DISTINCT cm.user_id) = 2
            ) pairs
            WHERE c.id = pairs.chat_id
        """))
    op.create_unique_constraint(
        "uq_chats_private_pair_key",
        "chats",
        ["private_pair_key"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_chats_private_pair_key", "chats", type_="unique")
    op.drop_column("chats", "private_pair_key")
    op.drop_constraint(
        "uq_messages_sender_client_message_id",
        "messages",
        type_="unique",
    )
    op.drop_column("messages", "client_message_id")
