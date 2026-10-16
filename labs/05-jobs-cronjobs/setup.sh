#!/usr/bin/env bash
# Lab 05 setup — seed 'batch' ns with CronJob 'reporter'.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists batch
ensure_namespace batch

k apply -f "$LAB_DIR/manifests/reporter.yaml" >/dev/null
wait_for "reporter produces a Job pod" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT -n batch get jobs \
        --no-headers 2>/dev/null | grep -q '^reporter-'"

info "lab 05 setup done — CronJob reporter (* * * * *) is running"
