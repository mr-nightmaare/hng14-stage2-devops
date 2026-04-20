#!/usr/bin/env bash
set -euo pipefail

# ── Integration Test Script ──
# Submits a job, polls for completion, asserts the final status.

FRONTEND_URL="http://localhost:3000"
MAX_RETRIES=30
RETRY_INTERVAL=2

echo "=== Integration Test ==="

# Step 1: Wait for frontend to be reachable
echo "Waiting for frontend to be reachable..."
for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf "$FRONTEND_URL/health" > /dev/null 2>&1; then
    echo "Frontend is up!"
    break
  fi
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "FAIL: Frontend did not become reachable in time"
    exit 1
  fi
  echo "  Attempt $i/$MAX_RETRIES — waiting ${RETRY_INTERVAL}s..."
  sleep "$RETRY_INTERVAL"
done

# Step 2: Submit a job
echo "Submitting a job..."
RESPONSE=$(curl -sf -X POST "$FRONTEND_URL/submit")
JOB_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['job_id'])")
echo "Job submitted: $JOB_ID"

if [ -z "$JOB_ID" ]; then
  echo "FAIL: No job_id returned"
  exit 1
fi

# Step 3: Poll for completion
echo "Polling for job completion..."
for i in $(seq 1 $MAX_RETRIES); do
  STATUS_RESPONSE=$(curl -sf "$FRONTEND_URL/status/$JOB_ID")
  STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))")
  echo "  Attempt $i/$MAX_RETRIES — status: $STATUS"

  if [ "$STATUS" = "completed" ]; then
    echo ""
    echo "=== PASS: Job $JOB_ID completed successfully ==="
    exit 0
  fi

  if [ "$STATUS" = "failed" ] || [ "$STATUS" = "error" ]; then
    echo "FAIL: Job ended with status: $STATUS"
    exit 1
  fi

  sleep "$RETRY_INTERVAL"
done

echo "FAIL: Job did not complete within timeout"
exit 1
