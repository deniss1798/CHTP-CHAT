"""add performance indexes

Revision ID: f6a7b8c9d0e1
Revises: b5c6d7e8f9a0
Create Date: 2026-04-27 21:15:00.000000
"""

from alembic import op


revision = "f6a7b8c9d0e1"
down_revision = "b5c6d7e8f9a0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_messages_chat_id_id",
        "messages",
        ["chat_id", "id"],
        unique=False,
    )
    op.create_index(
        "ix_messages_chat_id_created_at_id",
        "messages",
        ["chat_id", "created_at", "id"],
        unique=False,
    )
    op.create_index(
        "ix_chat_members_user_chat",
        "chat_members",
        ["user_id", "chat_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_chat_members_user_chat", table_name="chat_members")
    op.drop_index("ix_messages_chat_id_created_at_id", table_name="messages")
    op.drop_index("ix_messages_chat_id_id", table_name="messages")
