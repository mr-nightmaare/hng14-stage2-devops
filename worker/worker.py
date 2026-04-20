import redis
import time
import os
import signal
import sys

r = redis.Redis(
    host=os.environ.get("REDIS_HOST", "localhost"),
    port=int(os.environ.get("REDIS_PORT", 6379)),
    password=os.environ.get("REDIS_PASSWORD", None),
    decode_responses=True,
)

running = True


def shutdown_handler(signum, frame):
    global running
    print("Received shutdown signal, finishing current job...")
    running = False


signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)


def process_job(job_id):
    print(f"Processing job {job_id}")
    r.hset(f"job:{job_id}", "status", "processing")
    time.sleep(2)  # simulate work
    r.hset(f"job:{job_id}", "status", "completed")
    print(f"Done: {job_id}")


while running:
    try:
        job = r.brpop("job_queue", timeout=5)
        if job:
            _, job_id = job
            process_job(job_id)
    except redis.exceptions.ConnectionError as e:
        print(f"Redis connection error: {e}, retrying in 5s...")
        time.sleep(5)
    except Exception as e:
        print(f"Unexpected error: {e}")
        time.sleep(1)

print("Worker shut down gracefully.")
sys.exit(0)