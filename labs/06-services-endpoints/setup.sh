#!/usr/bin/env bash
# Lab 06 setup — seed 'services' ns with legacy-api + broken legacy-svc.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists services
ensure_namespace services

k apply -f "$LAB_DIR/manifests/legacy.yaml" >/dev/null
wait_rollout services legacy-api 180s

info "lab 06 setup done — legacy-api running; legacy-svc has no endpoints"
