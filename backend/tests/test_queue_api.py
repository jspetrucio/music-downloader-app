"""
Integration tests for Queue API endpoints

Run with: pytest tests/test_queue_api.py -v
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from app.core.database import get_db, Base
from app.models.queue_models import QueueStatus, QueuePriority

# Test database setup
TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    """Override database dependency for testing"""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def setup_database():
    """Create tables before each test, drop after"""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    """Test client fixture"""
    return TestClient(app)


class TestAddToQueue:
    """Test POST /api/v1/downloads/queue"""

    def test_add_valid_item(self, client):
        """Test adding valid item to queue"""
        response = client.post(
            "/api/v1/downloads/queue",
            json={
                "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                "format": "mp3",
                "priority": "normal"
            }
        )
        
        assert response.status_code == 201
        data = response.json()
        assert data["id"] == 1
        assert data["status"] == "pending"
        assert data["priority"] == "normal"
        assert data["position"] == 1

    def test_add_high_priority(self, client):
        """Test adding high priority item"""
        response = client.post(
            "/api/v1/downloads/queue",
            json={
                "url": "https://www.youtube.com/watch?v=test",
                "format": "m4a",
                "priority": "high"
            }
        )
        
        assert response.status_code == 201
        assert response.json()["priority"] == "high"

    def test_idempotency(self, client):
        """Test idempotency key prevents duplicates"""
        payload = {
            "url": "https://www.youtube.com/watch?v=test",
            "format": "mp3",
            "priority": "normal"
        }
        
        # First request
        response1 = client.post(
            "/api/v1/downloads/queue",
            json=payload,
            headers={"Idempotency-Key": "test-key-123"}
        )
        
        # Second request with same key
        response2 = client.post(
            "/api/v1/downloads/queue",
            json=payload,
            headers={"Idempotency-Key": "test-key-123"}
        )
        
        assert response1.status_code == 201
        assert response2.status_code == 201
        assert response1.json()["id"] == response2.json()["id"]

    def test_missing_url(self, client):
        """Test validation error for missing URL"""
        response = client.post(
            "/api/v1/downloads/queue",
            json={"format": "mp3"}
        )
        
        assert response.status_code == 422  # Validation error

    def test_invalid_format(self, client):
        """Test validation error for invalid format"""
        response = client.post(
            "/api/v1/downloads/queue",
            json={
                "url": "https://www.youtube.com/watch?v=test",
                "format": "wav"  # Invalid
            }
        )
        
        assert response.status_code == 422

    def test_invalid_priority(self, client):
        """Test validation error for invalid priority"""
        response = client.post(
            "/api/v1/downloads/queue",
            json={
                "url": "https://www.youtube.com/watch?v=test",
                "format": "mp3",
                "priority": "urgent"  # Invalid
            }
        )
        
        assert response.status_code == 422


class TestListQueue:
    """Test GET /api/v1/downloads/queue"""

    def test_list_empty_queue(self, client):
        """Test listing empty queue"""
        response = client.get("/api/v1/downloads/queue")
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 0
        assert len(data["items"]) == 0
        assert data["stats"]["pending"] == 0

    def test_list_multiple_items(self, client):
        """Test listing queue with multiple items"""
        # Add 3 items
        for i in range(3):
            client.post(
                "/api/v1/downloads/queue",
                json={
                    "url": f"https://www.youtube.com/watch?v=test{i}",
                    "format": "mp3"
                }
            )
        
        response = client.get("/api/v1/downloads/queue")
        
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 3
        assert len(data["items"]) == 3
        assert data["stats"]["pending"] == 3

    def test_filter_by_status(self, client):
        """Test filtering by status"""
        # Add item
        client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://www.youtube.com/watch?v=test", "format": "mp3"}
        )
        
        # Filter by pending
        response = client.get("/api/v1/downloads/queue?status=pending")
        assert response.status_code == 200
        assert len(response.json()["items"]) == 1
        
        # Filter by completed (none)
        response = client.get("/api/v1/downloads/queue?status=completed")
        assert response.status_code == 200
        assert len(response.json()["items"]) == 0

    def test_pagination(self, client):
        """Test pagination with limit and offset"""
        # Add 5 items
        for i in range(5):
            client.post(
                "/api/v1/downloads/queue",
                json={"url": f"https://youtube.com/watch?v={i}", "format": "mp3"}
            )
        
        # Get first 2
        response = client.get("/api/v1/downloads/queue?limit=2&offset=0")
        assert len(response.json()["items"]) == 2
        
        # Get next 2
        response = client.get("/api/v1/downloads/queue?limit=2&offset=2")
        assert len(response.json()["items"]) == 2

    def test_invalid_status_filter(self, client):
        """Test invalid status filter"""
        response = client.get("/api/v1/downloads/queue?status=invalid")
        assert response.status_code == 400


class TestGetQueueItem:
    """Test GET /api/v1/downloads/queue/{id}"""

    def test_get_existing_item(self, client):
        """Test getting existing item"""
        # Add item
        add_response = client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://www.youtube.com/watch?v=test", "format": "mp3"}
        )
        item_id = add_response.json()["id"]
        
        # Get item
        response = client.get(f"/api/v1/downloads/queue/{item_id}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == item_id
        assert data["url"] == "https://www.youtube.com/watch?v=test"

    def test_get_nonexistent_item(self, client):
        """Test getting non-existent item"""
        response = client.get("/api/v1/downloads/queue/99999")
        assert response.status_code == 404


class TestUpdatePriority:
    """Test PUT /api/v1/downloads/queue/{id}/priority"""

    def test_update_priority(self, client):
        """Test updating priority"""
        # Add item
        add_response = client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://www.youtube.com/watch?v=test", "format": "mp3", "priority": "normal"}
        )
        item_id = add_response.json()["id"]
        
        # Update priority
        response = client.put(
            f"/api/v1/downloads/queue/{item_id}/priority",
            json={"priority": "high"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["item"]["priority"] == "high"

    def test_update_nonexistent_item(self, client):
        """Test updating priority of non-existent item"""
        response = client.put(
            "/api/v1/downloads/queue/99999/priority",
            json={"priority": "high"}
        )
        assert response.status_code == 404


class TestDeleteQueueItem:
    """Test DELETE /api/v1/downloads/queue/{id}"""

    def test_delete_item(self, client):
        """Test deleting queue item"""
        # Add item
        add_response = client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://www.youtube.com/watch?v=test", "format": "mp3"}
        )
        item_id = add_response.json()["id"]
        
        # Delete item
        response = client.delete(f"/api/v1/downloads/queue/{item_id}")
        
        assert response.status_code == 200
        assert response.json()["success"] is True
        
        # Verify deleted
        get_response = client.get(f"/api/v1/downloads/queue/{item_id}")
        assert get_response.status_code == 404

    def test_delete_nonexistent_item(self, client):
        """Test deleting non-existent item"""
        response = client.delete("/api/v1/downloads/queue/99999")
        assert response.status_code == 404


class TestPauseResume:
    """Test pause and resume operations"""

    def test_pause_pending_item(self, client):
        """Test pausing pending item"""
        # Add item
        add_response = client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://www.youtube.com/watch?v=test", "format": "mp3"}
        )
        item_id = add_response.json()["id"]
        
        # Pause
        response = client.post(f"/api/v1/downloads/queue/{item_id}/pause")
        
        assert response.status_code == 200
        assert response.json()["item"]["status"] == "paused"

    def test_resume_paused_item(self, client):
        """Test resuming paused item"""
        # Add and pause item
        add_response = client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://www.youtube.com/watch?v=test", "format": "mp3"}
        )
        item_id = add_response.json()["id"]
        client.post(f"/api/v1/downloads/queue/{item_id}/pause")
        
        # Resume
        response = client.post(f"/api/v1/downloads/queue/{item_id}/resume")
        
        assert response.status_code == 200
        assert response.json()["item"]["status"] == "pending"

    def test_pause_nonexistent_item(self, client):
        """Test pausing non-existent item"""
        response = client.post("/api/v1/downloads/queue/99999/pause")
        assert response.status_code == 404

    def test_resume_nonexistent_item(self, client):
        """Test resuming non-existent item"""
        response = client.post("/api/v1/downloads/queue/99999/resume")
        assert response.status_code == 404


class TestQueueOrdering:
    """Test queue priority ordering"""

    def test_priority_ordering(self, client):
        """Test items are ordered by priority"""
        # Add low priority
        client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://youtube.com/watch?v=1", "format": "mp3", "priority": "low"}
        )
        
        # Add high priority
        response_high = client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://youtube.com/watch?v=2", "format": "mp3", "priority": "high"}
        )
        
        # Add normal priority
        client.post(
            "/api/v1/downloads/queue",
            json={"url": "https://youtube.com/watch?v=3", "format": "mp3", "priority": "normal"}
        )
        
        # High priority should be position 1
        assert response_high.json()["position"] == 1
        
        # List queue - high should be first
        list_response = client.get("/api/v1/downloads/queue?status=pending")
        items = list_response.json()["items"]
        assert items[0]["priority"] == "high"
        assert items[1]["priority"] == "normal"
        assert items[2]["priority"] == "low"


class TestRateLimit:
    """Test rate limiting (if enabled in test environment)"""

    def test_add_to_queue_rate_limit(self, client):
        """Test rate limit on adding to queue"""
        # This test may be skipped if rate limiting is disabled in tests
        # In production, should return 429 after limit exceeded
        pass


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
