#!/usr/bin/env bash
# Lab 02 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — pod web: Running, label, port
check_eq "pod web Running" "$(pod_phase pods web)" "Running"
check_jsonpath "web has label app=web" pod/web '{.metadata.labels.app}' 'web' -n pods
check_jsonpath "web exposes containerPort 80" \
    pod/web '{.spec.containers[0].ports[0].containerPort}' '80' -n pods

# Task 2 — pod busy: image, env, restartPolicy
check_eq "pod busy Running" "$(pod_phase pods busy)" "Running"
check_jsonpath "busy image is busybox:1.36" \
    pod/busy '{.spec.containers[0].image}' 'busybox:1.36' -n pods
check_jsonpath "busy has env GREETING=hello" \
    pod/busy '{.spec.containers[0].env[?(@.name=="GREETING")].value}' 'hello' -n pods
check_jsonpath "busy restartPolicy is Never" \
    pod/busy '{.spec.restartPolicy}' 'Never' -n pods

# Task 3 — crash-reason.txt contains DB_HOST
check_file_contains "crash-reason.txt names the missing key" \
    "$OUT_DIR/crash-reason.txt" 'DB_HOST'

# Task 4 — sidecar.log has heartbeat lines
check_file_contains "sidecar.log has heartbeat lines" \
    "$OUT_DIR/sidecar.log" 'sidecar heartbeat'

# Task 5 — status.txt equals the sidecar token
check_eq "status.txt holds the sidecar token" \
    "$(cat "$OUT_DIR/status.txt" 2>/dev/null | tr -d '[:space:]' || true)" \
    "sidecar-token-7f3a"

# Task 6 — /tmp/hello.txt inside busy contains world
check_eq "/tmp/hello.txt in busy contains world" \
    "$(k exec busy -n pods -- cat /tmp/hello.txt 2>/dev/null | tr -d '[:space:]' || true)" \
    "world"

# Task 7 — nginx.conf copied
check_file_contains "nginx.conf copied" "$OUT_DIR/nginx.conf" 'worker_processes'

# Task 8 — index.html captured via port-forward
check_file_contains "index.html from port-forward" \
    "$OUT_DIR/index.html" 'Welcome to nginx'

# Task 9 — web-node.txt matches actual node
check_eq "web-node.txt names the real node" \
    "$(cat "$OUT_DIR/web-node.txt" 2>/dev/null | tr -d '[:space:]' || true)" \
    "$(k get pod web -n pods -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo MISSING)"

# Task 10 — describe captured
check_file_contains "crasher-describe.txt saved" \
    "$OUT_DIR/crasher-describe.txt" 'Exit Code'

# Task 11 — crasher deleted
check_absent "pod crasher deleted" pod crasher -n pods

finish_checks
