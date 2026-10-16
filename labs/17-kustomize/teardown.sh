#!/usr/bin/env bash
# Lab 17 teardown — remove lab 17 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

k delete -k "$OUT_DIR/overlays/prod" >/dev/null 2>&1 || true
k delete -k "$OUT_DIR/overlays/dev" >/dev/null 2>&1 || true
delete_namespace_if_exists kz-dev
delete_namespace_if_exists kz-prod

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 17 teardown done"
