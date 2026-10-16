#!/usr/bin/env bash
# Lab 05 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — job pi
k delete job pi -n batch --ignore-not-found >/dev/null 2>&1 || true
k create job pi -n batch --image=perl:5.34.0 \
    -- perl -Mbignum=bpi -wle 'print bpi(2000)' >/dev/null
k wait --for=condition=complete job/pi -n batch --timeout=300s >/dev/null

# Task 2 — parallel-echo manifest
k apply -n batch -f - >/dev/null <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-echo
spec:
  completions: 6
  parallelism: 2
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "echo hello; sleep 2"]
EOF
k wait --for=condition=complete job/parallel-echo -n batch --timeout=180s >/dev/null

# Task 3 — must-fail
k apply -n batch -f - >/dev/null <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: must-fail
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
EOF
k wait --for=condition=failed job/must-fail -n batch --timeout=180s >/dev/null 2>&1 \
    || true

# Task 4 — deadline
k apply -n batch -f - >/dev/null <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: deadline
spec:
  activeDeadlineSeconds: 20
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "300"]
EOF
k wait --for=condition=failed job/deadline -n batch --timeout=90s >/dev/null 2>&1 \
    || true

# Task 5 — ttl-job
k apply -n batch -f - >/dev/null <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: ttl-job
spec:
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["echo", "done"]
EOF

# Task 6 — cronjob backup
k create cronjob backup -n batch --image=busybox:1.36 \
    --schedule="*/5 * * * *" --dry-run=client -o yaml \
    -- sh -c 'echo backing up' | k apply -f - >/dev/null

# Task 7 — cronjob knobs
k patch cronjob backup -n batch --type=merge -p \
    '{"spec":{"concurrencyPolicy":"Forbid","successfulJobsHistoryLimit":3,
              "failedJobsHistoryLimit":1,"startingDeadlineSeconds":100}}' \
    >/dev/null

# Task 8 — manual job from cronjob
k delete job reporter-manual -n batch --ignore-not-found >/dev/null 2>&1 || true
k create job reporter-manual --from=cronjob/reporter -n batch >/dev/null
k wait --for=condition=complete job/reporter-manual -n batch \
    --timeout=180s >/dev/null

# Task 9 — suspend reporter
k patch cronjob reporter -n batch --type=merge \
    -p '{"spec":{"suspend":true}}' >/dev/null

# Task 10 — save jobs list
k get jobs -n batch -o wide > "$OUT_DIR/jobs.txt"

# Task 11 — delete must-fail (pods cascade)
k delete job must-fail -n batch --ignore-not-found >/dev/null

info "lab 05 solved"
