"""add last_read_message_id to chat_members

Revision ID: a1b2c3d4e5f6
Revises: 7f2a9c1d4e50
Create Date: 2026-04-06

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "7f2a9c1d4e50"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "chat_members",
        sa.Column("last_read_message_id", sa.BigInteger(), nullable=True),
    )
    op.create_index(
        op.f("ix_chat_members_last_read_message_id"),
        "chat_members",
        ["last_read_message_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_chat_members_last_read_message_id",
        "chat_members",
        "messages",
        ["last_read_message_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_chat_members_last_read_message_id", "chat_members", type_="foreignkey")
    op.drop_index(op.f("ix_chat_members_last_read_message_id"), table_name="chat_members")
    op.drop_column("chat_members", "last_read_message_id")
