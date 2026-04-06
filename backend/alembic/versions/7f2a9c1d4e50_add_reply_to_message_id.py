"""add reply_to_message_id to messages

Revision ID: 7f2a9c1d4e50
Revises: 3b8cdbea68d6
Create Date: 2026-04-06

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "7f2a9c1d4e50"
down_revision: Union[str, Sequence[str], None] = "3b8cdbea68d6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "messages",
        sa.Column(
            "reply_to_message_id",
            sa.BigInteger(),
            nullable=True,
        ),
    )
    op.create_index(
        op.f("ix_messages_reply_to_message_id"),
        "messages",
        ["reply_to_message_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_messages_reply_to_message_id",
        "messages",
        "messages",
        ["reply_to_message_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_messages_reply_to_message_id", "messages", type_="foreignkey")
    op.drop_index(op.f("ix_messages_reply_to_message_id"), table_name="messages")
    op.drop_column("messages", "reply_to_message_id")
