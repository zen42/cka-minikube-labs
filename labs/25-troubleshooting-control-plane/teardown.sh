#!/usr/bin/env bash
# Lab 25 teardown — byte-restore the scheduler manifest from the setup
# backup, wait for the mirror pod, then clear lab resources.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
CP="$(control_plane_node)"

# restore the pristine manifest (backed up by setup before the break)
if [[ -f "$STATE_DIR/lab25-scheduler.yaml" ]]; then
    mk cp "$STATE_DIR/lab25-scheduler.yaml" /tmp/kube-scheduler.yaml \
        >/dev/null
    node_ssh "$CP" \
        "sudo mv /tmp/kube-scheduler.yaml \
            /etc/kubernetes/manifests/kube-scheduler.yaml" >/dev/null
    wait_for "kube-scheduler restored" 180 \
        bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pod \
            kube-scheduler-$CP -o \
            jsonpath='{.status.containerStatuses[0].ready}' \
            2>/dev/null | grep -q true" || true
    # backup served its purpose — drop it once the on-node manifest
    # provably matches it and the pod is Ready (retried: the kubelet
    # may bounce the pod once more after the file lands)
    backup_md5="$(md5sum "$STATE_DIR/lab25-scheduler.yaml" \
        | awk '{print $1}')"
    for _ in $(seq 1 24); do
        remote_md5="$(node_ssh "$CP" \
            "sudo md5sum /etc/kubernetes/manifests/kube-scheduler.yaml" \
            | awk '{print $1}' | tr -d '[:space:]')" || true
        ready="$(k -n kube-system get pod "kube-scheduler-$CP" \
            -o jsonpath='{.status.containerStatuses[0].ready}' \
            2>/dev/null || true)"
        if [[ "$remote_md5" == "$backup_md5" && "$ready" == "true" ]]; then
            rm -f "$STATE_DIR/lab25-scheduler.yaml"
            break
        fi
        sleep 5
    done
else
    warn "no scheduler-manifest backup — trying in-place sed repair"
    node_ssh "$CP" \
        "sudo sed -i 's|scheduler.conf.wrong|scheduler.conf|g' \
            /etc/kubernetes/manifests/kube-scheduler.yaml" \
        >/dev/null 2>&1 || true
fi

delete_namespace_if_exists ts-cp

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 25 teardown done"
