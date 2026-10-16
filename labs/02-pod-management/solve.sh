#!/usr/bin/env bash
# Lab 02 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — pod web
k run web --image=nginx:1.27 --port=80 --labels=app=web -n pods \
    --dry-run=client -o yaml | k apply -f - >/dev/null
wait_pod_ready pods web 120s

# Task 2 — pod busy
k run busy --image=busybox:1.36 --restart=Never \
    --env=GREETING=hello -n pods --command --dry-run=client -o yaml \
    -- sleep 3600 | k apply -f - >/dev/null
wait_pod_ready pods busy 120s

# Task 3 — fatal line from previous logs
k logs crasher -n pods --previous 2>/dev/null | grep FATAL \
    > "$OUT_DIR/crash-reason.txt" || k logs crasher -n pods | grep FATAL \
    > "$OUT_DIR/crash-reason.txt"

# Task 4 — sidecar logs, last 20 lines
k logs multi -n pods -c sidecar --tail=20 > "$OUT_DIR/sidecar.log"

# Task 5 — read /shared/status.txt from container app
k exec multi -n pods -c app -- cat /shared/status.txt > "$OUT_DIR/status.txt"

# Task 6 — create /tmp/hello.txt in busy
k exec busy -n pods -- sh -c 'echo world > /tmp/hello.txt'

# Task 7 — cp nginx.conf out of web
k cp pods/web:/etc/nginx/nginx.conf "$OUT_DIR/nginx.conf"

# Task 8 — port-forward + curl
k port-forward pod/web 8080:80 -n pods >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT
wait_for "port-forward listening on 8080" 30 \
    curl -sf -o /dev/null http://localhost:8080
curl -s http://localhost:8080 > "$OUT_DIR/index.html"
kill "$PF_PID" 2>/dev/null || true
trap - EXIT

# Task 9 — wait Ready, then record node
k wait --for=condition=Ready pod/web -n pods --timeout=60s
k get pod web -n pods -o jsonpath='{.spec.nodeName}' > "$OUT_DIR/web-node.txt"

# Task 10 — describe crasher
k describe pod crasher -n pods > "$OUT_DIR/crasher-describe.txt"

# Task 11 — delete crasher
k delete pod crasher -n pods --ignore-not-found >/dev/null

info "lab 02 solved"
