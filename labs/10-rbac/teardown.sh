#!/usr/bin/env bash
# Lab 10 teardown — remove lab 10 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists rbac
delete_if_exists rolebinding jane-ns-pods -n default
delete_if_exists clusterrolebinding ops-node-viewer
delete_if_exists clusterrole node-viewer
delete_if_exists clusterrole ns-pod-reader
delete_if_exists clusterrole monitoring
delete_if_exists clusterrole monitoring-endpoints
delete_if_exists csr jane

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 10 teardown done"
