"""add message pinning columns and polls/options/votes tables

Revision ID: k3l4m5n6o7p8
Revises: j2k3l4m5n6o7
Create Date: 2026-05-12

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "k3l4m5n6o7p8"
down_revision: Union[str, Sequence[str], None] = "j2k3l4m5n6o7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- messages: pin support -----------------------------------------------
    op.add_column(
        "messages",
        sa.Column("pinned_at", sa.DateTime(timezone=False), nullable=True),
    )
    op.add_column(
        "messages",
        sa.Column("pinned_by_user_id", sa.BigInteger(), nullable=True),
    )
    op.create_foreign_key(
        "fk_messages_pinned_by_user_id",
        "messages",
        "users",
        ["pinned_by_user_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_messages_chat_pinned",
        "messages",
        ["chat_id", "pinned_at"],
    )

    # --- polls ---------------------------------------------------------------
    op.create_table(
        "polls",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "message_id",
            sa.BigInteger(),
            sa.ForeignKey("messages.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("question", sa.Text(), nullable=False),
        sa.Column(
            "allows_multiple",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "is_anonymous",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "is_closed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "poll_options",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "poll_id",
            sa.BigInteger(),
            sa.ForeignKey("polls.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.UniqueConstraint("poll_id", "position", name="uq_poll_options_poll_position"),
    )

    op.create_table(
        "poll_votes",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "poll_id",
            sa.BigInteger(),
            sa.ForeignKey("polls.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "option_id",
            sa.BigInteger(),
            sa.ForeignKey("poll_options.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "user_id",
            sa.BigInteger(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=False),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "poll_id",
            "option_id",
            "user_id",
            name="uq_poll_votes_poll_option_user",
        ),
    )
    op.create_index(
        "ix_poll_votes_poll_user",
        "poll_votes",
        ["poll_id", "user_id"],
    )

    # --- message_mentions ----------------------------------------------------
    op.create_table(
        "message_mentions",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "message_id",
            sa.BigInteger(),
            sa.ForeignKey("messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.BigInteger(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "message_id", "user_id", name="uq_message_mentions_message_user"
        ),
    )
    op.create_index(
        "ix_message_mentions_user",
        "message_mentions",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_message_mentions_user", table_name="message_mentions")
    op.drop_table("message_mentions")

    op.drop_index("ix_poll_votes_poll_user", table_name="poll_votes")
    op.drop_table("poll_votes")
    op.drop_table("poll_options")
    op.drop_table("polls")

    op.drop_index("ix_messages_chat_pinned", table_name="messages")
    op.drop_constraint("fk_messages_pinned_by_user_id", "messages", type_="foreignkey")
    op.drop_column("messages", "pinned_by_user_id")
    op.drop_column("messages", "pinned_at")
