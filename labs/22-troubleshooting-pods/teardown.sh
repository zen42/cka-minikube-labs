#!/usr/bin/env bash
# Lab 22 teardown — remove lab 22 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists ts-pods
# task-8 debug pod lives in 'default' — sweep any leftovers
for p in $(k get pods -n default -o name 2>/dev/null \
        | grep 'node-debugger' || true); do
    k delete "$p" -n default --wait=true >/dev/null 2>&1 || true
done

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 22 teardown done"
