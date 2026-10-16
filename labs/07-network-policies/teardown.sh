#!/usr/bin/env bash
# Lab 07 teardown — removes lab state, keeps the cluster running.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists netpol
delete_namespace_if_exists other   # takes the team=platform label with it

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 07 teardown done"
