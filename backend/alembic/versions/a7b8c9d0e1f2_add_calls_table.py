"""add calls table

Revision ID: a7b8c9d0e1f2
Revises: f6a7b8c9d0e1
Create Date: 2026-04-27 21:25:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "a7b8c9d0e1f2"
down_revision = "f6a7b8c9d0e1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "calls",
        sa.Column("id", sa.BigInteger(), nullable=False),
        sa.Column("chat_id", sa.BigInteger(), nullable=False),
        sa.Column("initiator_id", sa.BigInteger(), nullable=True),
        sa.Column(
            "type",
            sa.String(length=32),
            nullable=False,
            server_default="voice",
        ),
        sa.Column(
            "status",
            sa.String(length=32),
            nullable=False,
            server_default="created",
        ),
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("client_call_id", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["chat_id"], ["chats.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["initiator_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_calls_id"), "calls", ["id"], unique=False)
    op.create_index(op.f("ix_calls_chat_id"), "calls", ["chat_id"], unique=False)
    op.create_index(
        op.f("ix_calls_initiator_id"),
        "calls",
        ["initiator_id"],
        unique=False,
    )
    op.create_index(op.f("ix_calls_status"), "calls", ["status"], unique=False)
    op.create_unique_constraint("uq_calls_client_call_id", "calls", ["client_call_id"])


def downgrade() -> None:
    op.drop_constraint("uq_calls_client_call_id", "calls", type_="unique")
    op.drop_index(op.f("ix_calls_status"), table_name="calls")
    op.drop_index(op.f("ix_calls_initiator_id"), table_name="calls")
    op.drop_index(op.f("ix_calls_chat_id"), table_name="calls")
    op.drop_index(op.f("ix_calls_id"), table_name="calls")
    op.drop_table("calls")
