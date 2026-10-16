#!/usr/bin/env bash
# Lab 11 setup — ns sa + legacy pod + unbound pod-lister Role.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists sa
delete_if_exists clusterrolebinding app-sa-view

ensure_namespace sa
k apply -f "$LAB_DIR/manifests/legacy.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/pod-lister.yaml" >/dev/null
wait_pod_ready sa legacy 180s

info "lab 11 setup done — legacy pod runs as default SA; pod-lister unbound"
