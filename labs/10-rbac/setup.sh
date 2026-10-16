#!/usr/bin/env bash
# Lab 10 setup — ns rbac + app deployment + the broken dev-can-view binding.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# clean stale task objects from a previous run (idempotent reset)
delete_namespace_if_exists rbac
delete_if_exists rolebinding jane-ns-pods -n default
delete_if_exists clusterrolebinding ops-node-viewer
delete_if_exists clusterrole node-viewer
delete_if_exists clusterrole ns-pod-reader
delete_if_exists clusterrole monitoring
delete_if_exists clusterrole monitoring-endpoints
delete_if_exists csr jane

ensure_namespace rbac
k apply -f "$LAB_DIR/manifests/app.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/dev-can-view.yaml" >/dev/null
wait_rollout rbac app 180s

info "lab 10 setup done — app running; dev-can-view dangles at 'pod-viewer'"
