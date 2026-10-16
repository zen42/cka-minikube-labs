#!/usr/bin/env bash
# Lab 02 teardown — removes lab state, keeps the cluster running.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists pods

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 02 teardown done"
