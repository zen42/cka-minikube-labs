#!/usr/bin/env bash
# Lab 14 teardown — remove lab 14 resources; nodes and cluster stay.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists sched
delete_if_exists priorityclass high-prio

for node in cka-labs cka-labs-m02 cka-labs-m03; do
    k label node "$node" disktype- >/dev/null 2>&1 || true
    k taint node "$node" dedicated:NoSchedule- >/dev/null 2>&1 || true
    k uncordon "$node" >/dev/null 2>&1 || true
done

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 14 teardown done (worker nodes remain — 'make reset-cluster' shrinks)"
