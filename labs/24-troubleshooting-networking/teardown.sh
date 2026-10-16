#!/usr/bin/env bash
# Lab 24 teardown — restore coredns replicas, remove lab 24 resources;
# cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# put DNS back the way the lab found it (backup made by setup)
if [[ -f "$STATE_DIR/lab24-coredns.json" ]]; then
    if restore_object "$STATE_DIR/lab24-coredns.json" \
        && wait_for "coredns restored" 180 \
            deploy_available kube-system coredns; then
        # backup served its purpose — drop it so a stale copy can't be
        # restored over a newer deployment later
        rm -f "$STATE_DIR/lab24-coredns.json"
    fi
else
    k -n kube-system scale deployment coredns --replicas=1 \
        >/dev/null 2>&1 || true
fi

delete_namespace_if_exists ts-net

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 24 teardown done"
