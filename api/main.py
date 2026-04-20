from fastapi import FastAPI
from fastapi.responses import JSONResponse
import redis
import uuid
import os

app = FastAPI()

r = redis.Redis(
    host=os.environ.get("REDIS_HOST", "localhost"),
    port=int(os.environ.get("REDIS_PORT", 6379)),
    password=os.environ.get("REDIS_PASSWORD", None),
    decode_responses=True,
)


@app.get("/health")
def health():
    try:
        r.ping()
        return {"status": "healthy"}
    except Exception:
        return JSONResponse(
            status_code=503, content={"status": "unhealthy"}
        )


@app.post("/jobs")
def create_job():
    job_id = str(uuid.uuid4())
    r.lpush("job_queue", job_id)
    r.hset(f"job:{job_id}", "status", "queued")
    return {"job_id": job_id}


@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    status = r.hget(f"job:{job_id}", "status")
    if not status:
        return JSONResponse(
            status_code=404, content={"error": "not found"}
        )
    return {"job_id": job_id, "status": status}
