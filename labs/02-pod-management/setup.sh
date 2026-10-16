#!/usr/bin/env bash
# Lab 02 setup — seed 'pods' namespace with 'crasher' and 'multi'.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# clean start state: wipe leftovers from a previous partial run
delete_namespace_if_exists pods
ensure_namespace pods

k apply -f "$LAB_DIR/manifests/crasher.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/multi.yaml" >/dev/null

# crasher must have restarted at least once so --previous logs exist
wait_for "crasher has restarted (CrashLoopBackOff)" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n pods get pod crasher \
        -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null \
        | grep -qE '^[1-9]'"

wait_for "multi is Running" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT -n pods get pod multi \
        -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Running"

info "lab 02 setup done — pods: crasher (crash-looping), multi (app+sidecar)"
