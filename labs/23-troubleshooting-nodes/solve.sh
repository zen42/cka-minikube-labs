#!/usr/bin/env bash
# Lab 23 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — survey: which node is NotReady?
k get nodes -o wide > "$OUT_DIR/nodes.txt"
k describe node cka-labs-m03 > "$OUT_DIR/describe-m03.txt" 2>&1 || true
k get nodes --no-headers | awk '$2 != "Ready" {print $1}' \
    > "$OUT_DIR/notready-node.txt"

# Task 2 — on the node itself: unit status + journal, then start it
node_ssh cka-labs-m03 "sudo systemctl status kubelet --no-pager" \
    > "$OUT_DIR/kubelet-status.txt" 2>&1 || true
node_ssh cka-labs-m03 "sudo journalctl -u kubelet --no-pager -n 50" \
    > "$OUT_DIR/kubelet-journal.txt" 2>&1 || true
node_ssh cka-labs-m03 \
    "sudo systemctl enable kubelet >/dev/null 2>&1; \
     sudo systemctl start kubelet" >/dev/null
wait_for "cka-labs-m03 Ready again" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT get node cka-labs-m03 \
        -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' \
        2>/dev/null | grep -q True"

# Task 3 — the nodeSelector'd workload can finally land on m03
wait_for "node-app available" 240 \
    deploy_available ts-nodes node-app

# Task 4 — bring m02 back into the scheduler's pool
k uncordon cka-labs-m02 >/dev/null

# Task 5 — lift the maintenance taint
k taint node cka-labs-m02 maintenance=true:NoSchedule- >/dev/null

# Task 6 — node-scoped events
k get events --field-selector involvedObject.kind=Node -A \
    > "$OUT_DIR/node-events.txt" 2>&1 || true

# Task 7 — resource usage + allocated resources summary
k top nodes > "$OUT_DIR/top-nodes.txt" 2>&1 || true
k describe node cka-labs \
    | sed -n '/Allocated resources/,/Events/p' \
    > "$OUT_DIR/alloc.txt"

# Task 8 — maintenance drill: drain m03, snapshot the node list, uncordon
k drain cka-labs-m03 --ignore-daemonsets --delete-emptydir-data \
    >/dev/null
k get nodes > "$OUT_DIR/drained.txt"
k uncordon cka-labs-m03 >/dev/null
wait_for "node-app rescheduled on m03" 240 \
    deploy_available ts-nodes node-app

# Task 9 — the Ready condition object itself
k get node cka-labs-m03 \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")]}' \
    > "$OUT_DIR/m03-ready.txt"
echo >> "$OUT_DIR/m03-ready.txt"

info "lab 23 solved"
