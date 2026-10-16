#!/usr/bin/env bash
# Lab 04 setup — seed 'deploy' ns with deployment 'api'.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists deploy
ensure_namespace deploy

k apply -f "$LAB_DIR/manifests/api.yaml" >/dev/null
wait_rollout deploy api 180s

info "lab 04 setup done — deployment api (nginx:1.26, 2 replicas) running"
