#!/usr/bin/env bash
# Lab 21 teardown — remove lab 21 resources; cluster (and its current
# etcd data — it IS the cluster) stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
CP="$(control_plane_node)"

delete_namespace_if_exists etcd-lab

node_ssh "$CP" "sudo rm -rf /var/lib/minikube/etcd-backup \
    /var/lib/minikube/etcd-restored \
    /var/lib/minikube/etcd.pre-restore" >/dev/null 2>&1 || true

# if a run died mid-restore with the manifest still parked in /tmp,
# put the backed-up copy back so the cluster can come up
if ! node_ssh "$CP" "sudo test -f /etc/kubernetes/manifests/etcd.yaml" \
        >/dev/null 2>&1; then
    if [[ -f "$STATE_DIR/lab21-etcd.yaml" ]]; then
        mk cp "$STATE_DIR/lab21-etcd.yaml" /tmp/etcd-manifest-backup.yaml \
            >/dev/null 2>&1 \
            && node_ssh "$CP" \
                "sudo mv /tmp/etcd-manifest-backup.yaml \
                    /etc/kubernetes/manifests/etcd.yaml" \
                >/dev/null 2>&1 || true
        info "restored etcd manifest from $STATE_DIR/lab21-etcd.yaml"
    else
        warn "etcd manifest missing and no backup found — see README recovery"
    fi
elif [[ -f "$STATE_DIR/lab21-etcd.yaml" ]]; then
    # backup served its purpose once the live manifest provably matches
    # it — drop it so a stale copy can't be restored later
    remote_md5="$(node_ssh "$CP" \
        "sudo md5sum /etc/kubernetes/manifests/etcd.yaml" \
        | awk '{print $1}' | tr -d '[:space:]')" || true
    if [[ -n "$remote_md5" && "$remote_md5" == \
            "$(md5sum "$STATE_DIR/lab21-etcd.yaml" \
                | awk '{print $1}')" ]]; then
        rm -f "$STATE_DIR/lab21-etcd.yaml"
    fi
fi

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 21 teardown done"
