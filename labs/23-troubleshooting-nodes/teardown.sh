#!/usr/bin/env bash
# Lab 23 teardown — revive every node, drop the taint, remove lab 23
# resources; nodes and cluster stay.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

for node in cka-labs cka-labs-m02 cka-labs-m03; do
    node_ssh "$node" "sudo systemctl start kubelet" >/dev/null 2>&1 \
        || true
    k uncordon "$node" >/dev/null 2>&1 || true
    k taint node "$node" maintenance:NoSchedule- >/dev/null 2>&1 || true
done

delete_namespace_if_exists ts-nodes

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 23 teardown done (worker nodes remain — 'make reset-cluster' shrinks)"
