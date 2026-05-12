"""add reply_to_message_id to messages

Revision ID: 7f2a9c1d4e50
Revises: 3b8cdbea68d6
Create Date: 2026-04-06

"""
from typing import Sequence, Union

from alembic import op
from sqlalchemy import text


revision: str = "7f2a9c1d4e50"
down_revision: Union[str, Sequence[str], None] = "3b8cdbea68d6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Колонка могла быть добавлена вручную или старой схемой — не падаем.
    op.execute(
        text(
            """
            DO $body$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM information_schema.columns
                    WHERE table_name = 'messages'
                      AND column_name = 'reply_to_message_id'
                ) THEN
                    ALTER TABLE messages ADD COLUMN reply_to_message_id BIGINT;
                END IF;
            END
            $body$ LANGUAGE plpgsql
            """
        )
    )
    op.create_index(
        op.f("ix_messages_reply_to_message_id"),
        "messages",
        ["reply_to_message_id"],
        unique=False,
        if_not_exists=True,
    )
    op.execute(
        text(
            """
            DO $body$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint c
                    JOIN pg_class t ON c.conrelid = t.oid
                    WHERE t.relname = 'messages'
                      AND c.conname = 'fk_messages_reply_to_message_id'
                ) THEN
                    ALTER TABLE messages
                    ADD CONSTRAINT fk_messages_reply_to_message_id
                    FOREIGN KEY (reply_to_message_id)
                    REFERENCES messages (id)
                    ON DELETE SET NULL;
                END IF;
            END
            $body$ LANGUAGE plpgsql
            """
        )
    )


def downgrade() -> None:
    op.drop_constraint("fk_messages_reply_to_message_id", "messages", type_="foreignkey")
    op.drop_index(op.f("ix_messages_reply_to_message_id"), table_name="messages")
    op.drop_column("messages", "reply_to_message_id")
