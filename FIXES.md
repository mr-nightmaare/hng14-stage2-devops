# FIXES.md — Bug Documentation

Every bug found in the starter repository, with file, line number, description, and fix.

---

## 1. `api/.env` — Hardcoded secret committed to version control

| | |
|---|---|
| **File** | `api/.env` |
| **Line** | 1 |
| **Problem** | The file contains `REDIS_PASSWORD=supersecretpassword123` — a plaintext credential tracked in git. This is a critical security vulnerability; anyone with repo access can read the password. |
| **Fix** | Deleted `api/.env` from git tracking (`git rm --cached api/.env`). Created a `.gitignore` to prevent `.env` files from being committed. Provided `.env.example` with placeholder values instead. |

---

## 2. No `.gitignore` file

| | |
|---|---|
| **File** | (missing) |
| **Line** | N/A |
| **Problem** | The repository had no `.gitignore`, which allowed `api/.env` (containing secrets), `node_modules/`, `__pycache__/`, and other artifacts to be tracked. |
| **Fix** | Created `.gitignore` at the project root with entries for `.env`, `node_modules/`, `__pycache__/`, `.pytest_cache/`, `*.pyc`, IDE files, and OS files. |

---

## 3. `api/main.py:8` — Redis host hardcoded to `localhost`

| | |
|---|---|
| **File** | `api/main.py` |
| **Line** | 8 |
| **Problem** | `r = redis.Redis(host="localhost", port=6379)` — In a containerized environment, each service runs in its own container. `localhost` refers to the container itself, not the Redis service. The API cannot connect to Redis. |
| **Fix** | Changed to `redis.Redis(host=os.environ.get("REDIS_HOST", "localhost"), port=int(os.environ.get("REDIS_PORT", 6379)), ...)`. The host is now configurable via the `REDIS_HOST` environment variable (set to `redis` in docker-compose). |

---

## 4. `api/main.py:8` — Redis connection has no password authentication

| | |
|---|---|
| **File** | `api/main.py` |
| **Line** | 8 |
| **Problem** | The `.env` file defined `REDIS_PASSWORD` but the `redis.Redis()` constructor never received a `password` parameter. If Redis is configured to require authentication (as it should be in production), all commands would fail with `NOAUTH`. |
| **Fix** | Added `password=os.environ.get("REDIS_PASSWORD", None)` to the Redis constructor. |

---

## 5. `api/main.py:4` — `os` module imported but never used

| | |
|---|---|
| **File** | `api/main.py` |
| **Line** | 4 |
| **Problem** | `import os` was present but `os.environ` was never called — the environment variables were never actually read. This was a dead import indicating the code was meant to use env vars but didn't. |
| **Fix** | The `os` module is now used in the Redis connection to read `REDIS_HOST`, `REDIS_PORT`, and `REDIS_PASSWORD` from environment variables. |

---

## 6. `api/main.py:20-21` — Returns HTTP 200 for non-existent jobs

| | |
|---|---|
| **File** | `api/main.py` |
| **Line** | 20-21 |
| **Problem** | `return {"error": "not found"}` returns a 200 OK status code when a job doesn't exist. Clients expecting proper HTTP semantics cannot distinguish between a successful response and a "not found" error. |
| **Fix** | Changed to `return JSONResponse(status_code=404, content={"error": "not found"})` to return a proper 404 Not Found HTTP status code. Added `from fastapi.responses import JSONResponse`. |

---

## 7. `worker/worker.py:6` — Redis host hardcoded to `localhost`

| | |
|---|---|
| **File** | `worker/worker.py` |
| **Line** | 6 |
| **Problem** | Same as API issue #3. `r = redis.Redis(host="localhost", port=6379)` will fail inside a container because `localhost` points to the worker container itself, not the Redis service. |
| **Fix** | Changed to use `os.environ.get("REDIS_HOST", "localhost")` and `os.environ.get("REDIS_PORT", 6379)`. |

---

## 8. `worker/worker.py:6` — Redis connection has no password authentication

| | |
|---|---|
| **File** | `worker/worker.py` |
| **Line** | 6 |
| **Problem** | Same as API issue #4. No `password` parameter in `redis.Redis()`. Worker cannot authenticate with a password-protected Redis instance. |
| **Fix** | Added `password=os.environ.get("REDIS_PASSWORD", None)` to the Redis constructor. |

---

## 9. `worker/worker.py:4` — `signal` module imported but never used

| | |
|---|---|
| **File** | `worker/worker.py` |
| **Line** | 4 |
| **Problem** | `import signal` is present but no signal handlers are registered. The worker has no graceful shutdown mechanism — when Docker sends `SIGTERM`, the process is killed immediately, potentially mid-job. Processed jobs could be left in an inconsistent state. |
| **Fix** | Added signal handlers for `SIGTERM` and `SIGINT` that set a `running = False` flag. The main loop checks this flag, allowing the current job to finish before exiting cleanly. |

---

## 10. `worker/worker.py:3` — `os` module imported but never used

| | |
|---|---|
| **File** | `worker/worker.py` |
| **Line** | 3 |
| **Problem** | Same as API issue #5. `import os` was present but `os.environ` was never called. |
| **Fix** | The `os` module is now used to read `REDIS_HOST`, `REDIS_PORT`, and `REDIS_PASSWORD` from environment variables. |

---

## 11. `worker/worker.py:14-18` — No error handling in main loop

| | |
|---|---|
| **File** | `worker/worker.py` |
| **Line** | 14-18 |
| **Problem** | The `while True` loop has no try/except. If `r.brpop()` or `process_job()` raises an exception (e.g., Redis connection lost temporarily), the entire worker process crashes and must be manually restarted. |
| **Fix** | Wrapped the main loop body in try/except. `redis.exceptions.ConnectionError` triggers a 5-second retry; unexpected exceptions are logged with a 1-second pause. The worker stays alive through transient failures. |

---

## 12. `worker/worker.py:14-18` — No graceful shutdown mechanism

| | |
|---|---|
| **File** | `worker/worker.py` |
| **Line** | 14-18 |
| **Problem** | `while True` runs indefinitely with no exit condition. Docker compose sends `SIGTERM` on shutdown, but the worker ignores it and must be forcefully killed after the timeout. This can corrupt in-progress jobs. |
| **Fix** | Changed `while True` to `while running`. A `shutdown_handler` function sets `running = False` on `SIGTERM`/`SIGINT`. The current job finishes, then the loop exits and the process terminates cleanly with `sys.exit(0)`. |

---

## 13. `frontend/app.js:6` — API URL hardcoded to `http://localhost:8000`

| | |
|---|---|
| **File** | `frontend/app.js` |
| **Line** | 6 |
| **Problem** | `const API_URL = "http://localhost:8000"` — In containers, the frontend cannot reach the API at `localhost:8000`. It needs to use the Docker service name (e.g., `http://api:8000`). |
| **Fix** | Changed to `const API_URL = process.env.API_URL \|\| "http://localhost:8000"`. The `docker-compose.yml` sets `API_URL=http://api:8000`. |

---

## 14. `frontend/app.js:29` — Port hardcoded to `3000`

| | |
|---|---|
| **File** | `frontend/app.js` |
| **Line** | 29 |
| **Problem** | `app.listen(3000, ...)` uses a hardcoded port. This prevents configuration via environment variables and doesn't follow the twelve-factor app principle. |
| **Fix** | Changed to `const PORT = process.env.PORT \|\| 3000; app.listen(PORT, '0.0.0.0', ...)`. Also added `'0.0.0.0'` binding so the server is accessible from outside the container. |

---

## 15. `frontend/views/index.html:35` — Infinite polling on error states

| | |
|---|---|
| **File** | `frontend/views/index.html` |
| **Line** | 35 |
| **Problem** | `if (data.status !== 'completed')` — The polling loop only stops when status is exactly `'completed'`. If the API returns an error (e.g., `{"error": "not found"}`) or the job fails, `data.status` is `undefined` and never equals `'completed'`, so polling continues forever. This causes infinite requests to the API. |
| **Fix** | Changed to check for error responses and terminal statuses: stops polling on `'completed'`, `'failed'`, or when `data.error` is present. Added try/catch around the fetch call to handle network errors. |

---

## Additional Improvements Made

| Change | Reason |
|--------|--------|
| Added `/health` endpoint to API | Required for Docker HEALTHCHECK and service orchestration |
| Added `/health` endpoint to Frontend | Required for Docker HEALTHCHECK |
| Added `decode_responses=True` to Redis connections | Eliminates manual `.decode()` calls on every Redis response |
| Added `"processing"` intermediate status to worker | Allows the dashboard to show real-time job progress |
| Renamed Redis queue key from `"job"` to `"job_queue"` | Avoids ambiguity with the `"job:{id}"` hash key pattern |
