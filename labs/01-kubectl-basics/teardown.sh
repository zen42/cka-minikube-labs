#!/usr/bin/env bash
# Lab 01 teardown — removes lab state, keeps the cluster running.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists basics
delete_namespace_if_exists cleanup-me

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 01 teardown done"
