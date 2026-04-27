"""add device and call perf indexes

Revision ID: c8d9e0f1a2b3
Revises: a7b8c9d0e1f2
Create Date: 2026-04-28 10:00:00.000000
"""

from alembic import op

revision = "c8d9e0f1a2b3"
down_revision = "a7b8c9d0e1f2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_device_tokens_user_updated_id",
        "device_tokens",
        ["user_id", "updated_at", "id"],
        unique=False,
    )
    op.create_index(
        "ix_calls_started_at_id",
        "calls",
        ["started_at", "id"],
        unique=False,
    )
    op.create_index(
        "ix_calls_chat_started_id",
        "calls",
        ["chat_id", "started_at", "id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_calls_chat_started_id", table_name="calls")
    op.drop_index("ix_calls_started_at_id", table_name="calls")
    op.drop_index("ix_device_tokens_user_updated_id", table_name="device_tokens")
