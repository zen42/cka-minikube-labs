#!/usr/bin/env bash
# Lab 11 teardown — remove lab 11 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists sa
delete_if_exists clusterrolebinding app-sa-view

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 11 teardown done"
