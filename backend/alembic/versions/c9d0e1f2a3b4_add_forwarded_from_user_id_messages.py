"""add messages.forwarded_from_user_id for forwards

Revision ID: c9d0e1f2a3b4
Revises: b2c3d4e5f6a7
Create Date: 2026-04-13

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c9d0e1f2a3b4"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "messages",
        sa.Column("forwarded_from_user_id", sa.BigInteger(), nullable=True),
    )
    op.create_foreign_key(
        "fk_messages_forwarded_from_user_id",
        "messages",
        "users",
        ["forwarded_from_user_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_messages_forwarded_from_user_id", "messages", type_="foreignkey")
    op.drop_column("messages", "forwarded_from_user_id")
