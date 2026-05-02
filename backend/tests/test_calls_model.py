from app.models.call import Call


def test_calls_table_contract_is_declared() -> None:
    columns = Call.__table__.columns
    indexes = {index.name for index in Call.__table__.indexes}

    assert "chat_id" in columns
    assert "initiator_id" in columns
    assert "type" in columns
    assert "status" in columns
    assert "started_at" in columns
    assert "accepted_at" in columns
    assert "ended_at" in columns
    assert "duration_seconds" in columns
    assert "client_call_id" in columns
    assert "ix_calls_chat_id" in indexes
    assert "ix_calls_status" in indexes
    assert "ix_calls_started_at_id" in indexes
    assert "ix_calls_chat_started_id" in indexes
