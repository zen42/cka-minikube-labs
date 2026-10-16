#!/usr/bin/env bash
# Lab 00 teardown — removes lab state, keeps the cluster running.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists playground

# reset the cka-labs context's default namespace
if kubectl config get-contexts "$KUBE_CONTEXT" >/dev/null 2>&1; then
    kubectl config set-context "$KUBE_CONTEXT" --namespace=default >/dev/null
    info "context $KUBE_CONTEXT default namespace reset to 'default'"
fi

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 00 teardown done (cluster '$MINIKUBE_PROFILE' left running)"
