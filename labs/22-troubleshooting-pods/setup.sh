#!/usr/bin/env bash
# Lab 22 setup — seed ns ts-pods with a pile of broken workloads.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists ts-pods
ensure_namespace ts-pods

for f in "$LAB_DIR"/manifests/*.yaml; do
    k apply -n ts-pods -f "$f" >/dev/null
done

# give the failure modes time to surface
sleep 15
info "seeded state:"
k get pods -n ts-pods --no-headers 2>/dev/null \
    | awk '{printf "  %-28s %s\n", $1, $3}' || true

info "lab 22 setup done — everything above is yours to fix"
