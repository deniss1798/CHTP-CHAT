"""chat_members is_pinned

Revision ID: i9j0k1l2m3n4
Revises: h1i2j3k4l5m6
Create Date: 2026-04-28

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "i9j0k1l2m3n4"
down_revision: Union[str, Sequence[str], None] = "h1i2j3k4l5m6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "chat_members",
        sa.Column(
            "is_pinned",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.create_index(
        "ix_chat_members_user_pinned",
        "chat_members",
        ["user_id", "is_pinned"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_chat_members_user_pinned", table_name="chat_members")
    op.drop_column("chat_members", "is_pinned")
