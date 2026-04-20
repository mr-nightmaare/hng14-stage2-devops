# Job Processing System

A distributed job processing system with three services: a **Frontend** (Node.js/Express), an **API** (Python/FastAPI), and a **Worker** (Python), connected through **Redis**.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Frontend   │────▶│     API      │────▶│    Redis     │
│  (Node.js)   │     │  (FastAPI)   │     │   (Queue)    │
│  Port 3000   │     │  Port 8000   │     │  Port 6379   │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                 │
                                          ┌──────▼──────┐
                                          │    Worker    │
                                          │  (Python)    │
                                          └─────────────┘
```

**Flow:**
1. User submits a job via the Frontend dashboard
2. Frontend proxies the request to the API
3. API creates a job ID, pushes it to the Redis queue, sets status to `queued`
4. Worker picks up the job from the queue, sets status to `processing`, simulates work, then sets status to `completed`
5. Frontend polls the API for status updates and displays progress

## Prerequisites

- **Docker** (v20.10+) and **Docker Compose** (v2.0+)
- **Git**

Verify installation:
```bash
docker --version
docker compose version
git --version
```

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/mr-nightmaare/hng14-stage2-devops.git
cd hng14-stage2-devops
```

### 2. Set up environment variables

```bash
cp .env.example .env
```

Edit `.env` and set a strong Redis password:
```
REDIS_PASSWORD=your_secure_password_here
REDIS_HOST=redis
REDIS_PORT=6379
API_URL=http://api:8000
FRONTEND_PORT=3000
PORT=3000
```

### 3. Build and start all services

```bash
docker compose up -d --build
```

### 4. Verify everything is running

```bash
docker compose ps
```

**Expected output** — all services should show `healthy`:
```
NAME        SERVICE    STATUS                 PORTS
...-api-1       api        running (healthy)
...-frontend-1  frontend   running (healthy)   0.0.0.0:3000->3000/tcp
...-redis-1     redis      running (healthy)
...-worker-1    worker     running (healthy)
```

### 5. Use the application

Open your browser and navigate to: **http://localhost:3000**

1. Click **"Submit New Job"**
2. Watch the job status change: `queued` → `processing` → `completed`
3. Submit multiple jobs and track them all in real-time

### 6. Verify via API directly

```bash
# Check API health
curl http://localhost:3000/health

# Submit a job
curl -X POST http://localhost:3000/submit

# Check job status (replace JOB_ID with actual ID)
curl http://localhost:3000/status/JOB_ID
```

## Stopping the Stack

```bash
docker compose down        # Stop and remove containers
docker compose down -v     # Also remove volumes
```

## Running Tests

### API Unit Tests

```bash
cd api
pip install -r requirements.txt
pytest tests/ -v --cov=main --cov-report=term
```

## Project Structure

```
.
├── api/
│   ├── Dockerfile           # Multi-stage production Dockerfile
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── tests/
│       └── test_main.py     # Unit tests (pytest)
├── frontend/
│   ├── Dockerfile           # Multi-stage production Dockerfile
│   ├── app.js               # Express application
│   ├── package.json         # Node.js dependencies
│   └── views/
│       └── index.html       # Dashboard UI
├── worker/
│   ├── Dockerfile           # Multi-stage production Dockerfile
│   └── worker.py            # Job processing worker
├── scripts/
│   ├── deploy.sh            # Rolling deployment script
│   └── integration-test.sh  # End-to-end integration test
├── .github/
│   └── workflows/
│       └── ci-cd.yml        # CI/CD pipeline
├── docker-compose.yml       # Full stack orchestration
├── .env.example             # Environment variable template
├── .gitignore               # Git exclusion rules
├── FIXES.md                 # Bug documentation
└── README.md                # This file
```

## CI/CD Pipeline

The GitHub Actions pipeline runs six stages in strict order:

| Stage | Description |
|-------|-------------|
| **Lint** | flake8 (Python), eslint (JavaScript), hadolint (Dockerfiles) |
| **Test** | pytest with coverage report |
| **Build** | Build & push images to local Docker registry |
| **Security Scan** | Trivy scan — fails on CRITICAL findings |
| **Integration Test** | Full stack E2E test inside the runner |
| **Deploy** | Rolling update (main branch only) |

A failure in any stage prevents all subsequent stages from running.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_PASSWORD` | Redis authentication password | *(required)* |
| `REDIS_HOST` | Redis hostname | `redis` |
| `REDIS_PORT` | Redis port | `6379` |
| `API_URL` | Internal API URL for frontend | `http://api:8000` |
| `FRONTEND_PORT` | Host port for frontend | `3000` |
| `PORT` | Frontend listening port | `3000` |
