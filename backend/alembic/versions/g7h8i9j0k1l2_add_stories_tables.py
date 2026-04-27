"""add stories and story_views

Revision ID: g7h8i9j0k1l2
Revises: f6a7b8c9d0e1
Create Date: 2026-04-28
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "g7h8i9j0k1l2"
down_revision: Union[str, Sequence[str], None] = "f6a7b8c9d0e1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "stories",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("media_key", sa.Text(), nullable=False),
        sa.Column("media_type", sa.String(length=20), nullable=False),
        sa.Column("caption", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.text("now()"), nullable=True),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_stories_id", "stories", ["id"], unique=False)
    op.create_index("ix_stories_user_id", "stories", ["user_id"], unique=False)
    op.create_index("ix_stories_expires_at", "stories", ["expires_at"], unique=False)
    op.create_index("ix_stories_user_expires", "stories", ["user_id", "expires_at"], unique=False)

    op.create_table(
        "story_views",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("story_id", sa.BigInteger(), nullable=False),
        sa.Column("viewer_user_id", sa.BigInteger(), nullable=False),
        sa.Column("viewed_at", sa.DateTime(), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["story_id"], ["stories.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["viewer_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("story_id", "viewer_user_id", name="uq_story_views_story_viewer"),
    )
    op.create_index("ix_story_views_story_id", "story_views", ["story_id"], unique=False)
    op.create_index("ix_story_views_viewer_user_id", "story_views", ["viewer_user_id"], unique=False)
    op.create_index("ix_story_views_viewer", "story_views", ["viewer_user_id"], unique=False)


def downgrade() -> None:
    op.drop_table("story_views")
    op.drop_table("stories")
