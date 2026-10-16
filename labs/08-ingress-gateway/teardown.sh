#!/usr/bin/env bash
# Lab 08 teardown — removes lab state; NGF + CRDs stay installed.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# deleting the namespace removes the Gateway; NGF tears down the data plane
# (svc apps-gateway-nginx) with it.
delete_namespace_if_exists ingress

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 08 teardown done (NGF control plane left installed)"
