#!/usr/bin/env bash
# Lab 07 setup — seed 'netpol' (frontend/backend/db) and 'other' (outsider).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists netpol
delete_namespace_if_exists other
ensure_namespace netpol
ensure_namespace other

k apply -f "$LAB_DIR/manifests/frontend.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/backend.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/db.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/outsider.yaml" >/dev/null

for pod in frontend backend db; do
    wait_pod_ready netpol "$pod" 180s
done
wait_pod_ready other outsider 180s

info "lab 07 setup done — pods frontend/backend/db (netpol), outsider (other)"
