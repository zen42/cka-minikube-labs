#!/usr/bin/env bash
# Lab 25 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
CP="$(control_plane_node)"

# Task 1 — identification
check_file_contains "kube-system-pods.txt lists the scheduler" \
    "$OUT_DIR/kube-system-pods.txt" 'kube-scheduler'
check_eq "broken-component.txt names the scheduler" \
    "$(tr -d '[:space:]' < "$OUT_DIR/broken-component.txt" \
        2>/dev/null || true)" 'kube-scheduler'

# Task 2 — the logs finger the bad path
check "scheduler.log fingers the wrong config" \
    bash -c "grep -qE 'scheduler.conf.wrong|no such file' \
        '$OUT_DIR/scheduler.log' 2>/dev/null"

# Task 3 — fixed and scheduling
check_jsonpath "kube-scheduler pod Ready" \
    "pod/kube-scheduler-$CP" \
    '{.status.containerStatuses[0].ready}' 'true' -n kube-system
check "stuck deployment finally available" \
    deploy_available ts-cp stuck

# Task 4 — health endpoints
check_file_contains "livez.txt passed" \
    "$OUT_DIR/livez.txt" 'livez check passed'
check_file_contains "readyz.txt passed" \
    "$OUT_DIR/readyz.txt" 'readyz check passed'

# Task 5 — static pod anatomy
check_file_contains "static-pod-path.txt points at manifests dir" \
    "$OUT_DIR/static-pod-path.txt" '/etc/kubernetes/manifests'
check_file_contains "static-manifests.txt lists apiserver" \
    "$OUT_DIR/static-manifests.txt" 'kube-apiserver'
check_file_contains "static-manifests.txt lists etcd" \
    "$OUT_DIR/static-manifests.txt" 'etcd'

# Task 6 — crictl evidence
check_file_contains "apiserver-ps.txt shows the container" \
    "$OUT_DIR/apiserver-ps.txt" 'apiserver'
check "apiserver-log.txt is non-empty" \
    test -s "$OUT_DIR/apiserver-log.txt"

# Task 7 — certificates
check_file_contains "apiserver-cert.txt shows expiry" \
    "$OUT_DIR/apiserver-cert.txt" 'notAfter'
check_file_contains "apiserver-san.txt covers kubernetes.default" \
    "$OUT_DIR/apiserver-san.txt" 'kubernetes.default'

# Task 8 — mirror pod owner
check_file_contains "mirror pod owned by the Node" \
    "$OUT_DIR/apiserver-owner.txt" 'Node'

# Task 9 — liveness probe
check_file_contains "cm-liveness.txt captured" \
    "$OUT_DIR/cm-liveness.txt" 'Liveness'

# Task 10 — kubelet journal
check_file_contains "kubelet-scheduler.txt mentions the scheduler" \
    "$OUT_DIR/kubelet-scheduler.txt" 'scheduler'

finish_checks
