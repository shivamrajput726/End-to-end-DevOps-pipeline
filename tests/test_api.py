from fastapi.testclient import TestClient

from app.main import create_app


def test_health() -> None:
    client = TestClient(create_app())
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_items_lifecycle() -> None:
    client = TestClient(create_app())

    resp = client.get("/api/v1/items")
    assert resp.status_code == 200
    assert resp.json() == []

    resp = client.post("/api/v1/items", json={"name": "hello"})
    assert resp.status_code == 201
    created = resp.json()
    assert created["name"] == "hello"
    assert "id" in created

    resp = client.get("/api/v1/items")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


def test_metrics_exposed() -> None:
    client = TestClient(create_app())
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "http" in resp.text.lower()
