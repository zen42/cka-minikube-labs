#!/usr/bin/env bash
# Lab 23 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — survey artefacts
check_file_contains "nodes.txt lists the cluster" \
    "$OUT_DIR/nodes.txt" 'cka-labs'
check_file_contains "describe-m03.txt has node Conditions" \
    "$OUT_DIR/describe-m03.txt" 'Conditions'
check_file_contains "notready-node.txt names the broken node" \
    "$OUT_DIR/notready-node.txt" 'cka-labs-m03'

# Task 2 — kubelet evidence + node actually Ready
check_file_contains "kubelet-status.txt recorded the unit state" \
    "$OUT_DIR/kubelet-status.txt" 'kubelet'
check_file_contains "kubelet-journal.txt has journal lines" \
    "$OUT_DIR/kubelet-journal.txt" 'kubelet'
check_jsonpath "cka-labs-m03 is Ready" \
    node/cka-labs-m03 \
    '{.status.conditions[?(@.type=="Ready")].status}' 'True'

# Task 3 — nodeSelector workload recovered
check "node-app is available" deploy_available ts-nodes node-app
_ready="$(k get deploy node-app -n ts-nodes \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
check_eq "node-app has 2 ready replicas" "$_ready" '2'

# Task 4 — m02 schedulable again
_unsched="$(k get node cka-labs-m02 \
    -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)"
check_eq "cka-labs-m02 uncordoned" "$_unsched" ''

# Task 5 — taint removed
_taints="$(k get node cka-labs-m02 -o jsonpath='{.spec.taints}' \
    2>/dev/null || true)"
check_eq "cka-labs-m02 has no taints" "$_taints" ''

# Task 6 — node events captured
check "node-events.txt is non-empty" \
    test -s "$OUT_DIR/node-events.txt"

# Task 7 — metrics + allocation summary
check_file_contains "top-nodes.txt lists cka-labs" \
    "$OUT_DIR/top-nodes.txt" 'cka-labs'
check_file_contains "alloc.txt has Allocated resources" \
    "$OUT_DIR/alloc.txt" 'Allocated resources'

# Task 8 — drain recorded; node back to schedulable
check_file_contains "drained.txt shows SchedulingDisabled" \
    "$OUT_DIR/drained.txt" 'SchedulingDisabled'
_unsched3="$(k get node cka-labs-m03 \
    -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)"
check_eq "cka-labs-m03 schedulable after uncordon" "$_unsched3" ''

# Task 9 — Ready condition saved
check_file_contains "m03-ready.txt shows Ready True" \
    "$OUT_DIR/m03-ready.txt" 'True'

finish_checks
