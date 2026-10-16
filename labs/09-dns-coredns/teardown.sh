#!/usr/bin/env bash
# Lab 09 teardown — restore coredns ConfigMap, remove lab state.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# restore the pre-lab Corefile (safe even if setup never ran)
if [[ -f "$STATE_DIR/09-coredns.yaml" ]]; then
    if k get ns kube-system >/dev/null 2>&1 \
        && k -n kube-system get cm coredns >/dev/null 2>&1; then
        restore_object "$STATE_DIR/09-coredns.yaml"
        k -n kube-system rollout restart deployment coredns >/dev/null
        wait_rollout kube-system coredns 180s
        info "coredns ConfigMap restored and restarted"
    fi
    rm -f "$STATE_DIR/09-coredns.yaml"
fi

delete_namespace_if_exists dns
delete_namespace_if_exists dns-other

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 09 teardown done"
