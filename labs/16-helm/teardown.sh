#!/usr/bin/env bash
# Lab 16 teardown — remove lab 16 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

for rel in webapp frontend; do
    h uninstall "$rel" -n helm >/dev/null 2>&1 || true
done
delete_namespace_if_exists helm
h repo remove podinfo >/dev/null 2>&1 || true

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 16 teardown done"
