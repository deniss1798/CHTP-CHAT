"""Этап 12: X-Request-ID, readiness (DB), correlation with perf logging."""

import app.main as main_app
from app.core.request_id_middleware import REQUEST_ID_HEADER
from app.main import app
from fastapi.testclient import TestClient


def test_x_request_id_generated_on_health() -> None:
    c = TestClient(app)
    r = c.get("/health")
    assert r.status_code == 200
    assert REQUEST_ID_HEADER in r.headers
    assert len(r.headers[REQUEST_ID_HEADER]) >= 8


def test_x_request_id_echoes_client_header() -> None:
    c = TestClient(app)
    rid = "test-req-abc-123"
    r = c.get("/health", headers={REQUEST_ID_HEADER: rid})
    assert r.headers[REQUEST_ID_HEADER] == rid


def test_ready_200_and_503_depends_on_db_check(monkeypatch) -> None:
    c = TestClient(app)
    monkeypatch.setattr(main_app, "_db_ready", lambda: True)
    r = c.get("/ready")
    assert r.status_code == 200
    assert r.json() == {"status": "ready"}
    r2 = c.get("/api/ready")
    assert r2.status_code == 200

    monkeypatch.setattr(main_app, "_db_ready", lambda: False)
    assert c.get("/ready").status_code == 503
    assert c.get("/api/ready").status_code == 503


def test_realtime_metrics_endpoint_shape() -> None:
    c = TestClient(app)
    r = c.get("/metrics/realtime")
    assert r.status_code == 200
    data = r.json()
    assert "chat_connections" in data
    assert "inbox_connections" in data
    assert "send_error_total" in data
