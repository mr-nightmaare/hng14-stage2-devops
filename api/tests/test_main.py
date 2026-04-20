import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient


@pytest.fixture
def mock_redis():
    """Create a mock Redis instance for testing."""
    with patch("main.r") as mock_r:
        mock_r.ping.return_value = True
        yield mock_r


@pytest.fixture
def client(mock_redis):
    """Create a test client with mocked Redis."""
    from main import app
    return TestClient(app)


def test_health_endpoint(client, mock_redis):
    """Test that /health returns healthy when Redis is reachable."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


def test_health_endpoint_unhealthy(client, mock_redis):
    """Test that /health returns 503 when Redis is unreachable."""
    mock_redis.ping.side_effect = Exception("Connection refused")
    response = client.get("/health")
    assert response.status_code == 503
    data = response.json()
    assert data["status"] == "unhealthy"


def test_create_job(client, mock_redis):
    """Test that POST /jobs creates a job and returns a job_id."""
    response = client.post("/jobs")
    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data
    assert len(data["job_id"]) == 36  # UUID format

    # Verify Redis interactions
    mock_redis.lpush.assert_called_once()
    mock_redis.hset.assert_called_once()

    # Check the queue name and status
    args = mock_redis.lpush.call_args
    assert args[0][0] == "job_queue"

    hset_args = mock_redis.hset.call_args
    assert hset_args[0][1] == "status"
    assert hset_args[0][2] == "queued"


def test_get_job_found(client, mock_redis):
    """Test that GET /jobs/{id} returns correct status for existing job."""
    mock_redis.hget.return_value = "completed"
    job_id = "test-job-1234"

    response = client.get(f"/jobs/{job_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["job_id"] == job_id
    assert data["status"] == "completed"

    mock_redis.hget.assert_called_once_with(f"job:{job_id}", "status")


def test_get_job_not_found(client, mock_redis):
    """Test that GET /jobs/{id} returns 404 for non-existent job."""
    mock_redis.hget.return_value = None
    job_id = "nonexistent-job"

    response = client.get(f"/jobs/{job_id}")
    assert response.status_code == 404
    data = response.json()
    assert data["error"] == "not found"


def test_create_multiple_jobs(client, mock_redis):
    """Test that creating multiple jobs produces unique IDs."""
    response1 = client.post("/jobs")
    response2 = client.post("/jobs")

    data1 = response1.json()
    data2 = response2.json()

    assert data1["job_id"] != data2["job_id"]
