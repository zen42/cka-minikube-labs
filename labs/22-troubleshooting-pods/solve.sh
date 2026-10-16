#!/usr/bin/env bash
# Lab 22 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — img-typo: ImagePullBackOff on a bogus tag
k set image deployment/img-typo app=nginx:1.27 -n ts-pods >/dev/null
wait_rollout ts-pods img-typo 180s

# Task 2 — crash-app: read the exit code from lastState, then recreate
# with FOO set and a guarded sleep loop
wait_for "crash-app lastState recorded" 90 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ts-pods get pod crash-app \
        -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' \
        2>/dev/null | grep -q ."
k get pod crash-app -n ts-pods \
    -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' \
    > "$OUT_DIR/crash-exit-code.txt"
echo >> "$OUT_DIR/crash-exit-code.txt"
# pod spec is immutable — write the fix to a file and let
# `replace --force` delete + recreate
cat > "$OUT_DIR/crash-app.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: crash-app
  namespace: ts-pods
spec:
  containers:
  - name: app
    image: busybox:1.36
    env:
    - {name: FOO, value: bar}
    command:
    - sh
    - -c
    - '[ -n "$FOO" ] || { echo "fatal: FOO is not set"; exit 3; }; sleep 3600'
EOF
k replace --force -f "$OUT_DIR/crash-app.yaml" >/dev/null
wait_pod_ready ts-pods crash-app 120s

# Task 3 — probe-fail: readiness probe hits the wrong port
k patch deployment probe-fail -n ts-pods --type=strategic -p \
    '{"spec":{"template":{"spec":{"containers":[{"name":"app","readinessProbe":{"httpGet":{"port":80}}}]}}}}' \
    >/dev/null
wait_rollout ts-pods probe-fail 180s

# Task 4 — oom-app: record the OOMKilled reason + exit code, recreate
# with a sane limit AND a bounded workload
wait_for "oom-app OOMKilled recorded" 240 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ts-pods get pod oom-app \
        -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' \
        2>/dev/null | grep -q OOMKilled"
k get pod oom-app -n ts-pods \
    -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason} {.status.containerStatuses[0].lastState.terminated.exitCode}' \
    > "$OUT_DIR/oom-reason.txt"
echo >> "$OUT_DIR/oom-reason.txt"
cat > "$OUT_DIR/oom-app.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: oom-app
  namespace: ts-pods
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - 'head -c 8M /dev/zero | tail -c 1 >/dev/null; sleep 3600'
    resources:
      limits:
        memory: 64Mi
EOF
k replace --force -f "$OUT_DIR/oom-app.yaml" >/dev/null
wait_pod_ready ts-pods oom-app 120s

# Task 5 — pending-app: 100 cores will never schedule; record the
# scheduler's reason, then request a sane amount
k describe pod pending-app -n ts-pods 2>/dev/null \
    | grep -m1 'Insufficient' > "$OUT_DIR/pending-reason.txt" || true
cat > "$OUT_DIR/pending-app.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pending-app
  namespace: ts-pods
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: 100m
EOF
k replace --force -f "$OUT_DIR/pending-app.yaml" >/dev/null
wait_pod_ready ts-pods pending-app 120s

# Task 6 — cm-missing: CreateContainerConfigError; creating the
# ConfigMap is the whole fix (kubelet retries on its own)
k create configmap app-settings -n ts-pods \
    --from-literal=MODE=prod \
    --dry-run=client -o yaml | k apply -f - >/dev/null
wait_pod_ready ts-pods cm-missing 120s

# Task 7 — quiet: ephemeral debug container (the pause image has no
# shell to exec into); the pod must be scheduled/Running first
wait_pod_ready ts-pods quiet 120s
k debug quiet -n ts-pods --image=busybox:1.36 --target=quiet \
    -- sleep 3600 >/dev/null

# Task 8 — node debug pod: hostname via chroot, then clean it up
dbg="$(k get pods -n default --no-headers -o custom-columns=:.metadata.name \
    | grep 'node-debugger' | head -1 || true)"
if [[ -z "$dbg" ]]; then
    k debug "node/$(control_plane_node)" -n default --image=busybox:1.36 \
        -- chroot /host cat /etc/hostname >/dev/null 2>&1 || true
    dbg="$(k get pods -n default --no-headers \
        -o custom-columns=:.metadata.name \
        | grep 'node-debugger' | head -1)"
fi
wait_for "node debugger pod completed" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n default get pod $dbg \
        -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Succeeded"
k logs "$dbg" -n default > "$OUT_DIR/node-hostname.txt"
k delete pod "$dbg" -n default --wait=true >/dev/null

# Task 9 — pull the sidecar's recent log lines
k logs sidecar-app -n ts-pods -c sidecar --tail=5 \
    > "$OUT_DIR/sidecar.log"

# Task 10 — events summary + prove the probe fix actually landed
k get events -n ts-pods --sort-by=.lastTimestamp \
    > "$OUT_DIR/events.txt" 2>&1 || true
k wait --for=condition=Ready pod -l app=probe-fail -n ts-pods \
    --timeout=60s >/dev/null

info "lab 22 solved"
