"""chat_members archive and mute

Revision ID: h1i2j3k4l5m6
Revises: c8d9e0f1a2b3
Create Date: 2026-04-28

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "h1i2j3k4l5m6"
down_revision: Union[str, Sequence[str], None] = "c8d9e0f1a2b3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "chat_members",
        sa.Column(
            "is_archived",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "chat_members",
        sa.Column(
            "notifications_muted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.create_index(
        "ix_chat_members_user_archived",
        "chat_members",
        ["user_id", "is_archived"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_chat_members_user_archived", table_name="chat_members")
    op.drop_column("chat_members", "notifications_muted")
    op.drop_column("chat_members", "is_archived")
