#!/usr/bin/env bash
# Lab 03 setup — seed 'config' ns with the broken 'reader' deployment.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists config
ensure_namespace config

# 'reader' references ConfigMap app-config which does not exist yet —
# pods sit in CreateContainerConfigError until the learner creates it.
k apply -f "$LAB_DIR/manifests/reader.yaml" >/dev/null

wait_for "reader pods blocked (CreateContainerConfigError)" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT -n config get pods \
        -l app=reader -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' \
        2>/dev/null | grep -q CreateContainerConfigError"

info "lab 03 setup done — 'reader' is broken until you create ConfigMap app-config"
