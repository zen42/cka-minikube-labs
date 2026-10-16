#!/usr/bin/env bash
# Lab 26 teardown — ns, PV, node label, etcd snapshot, output dir.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
CP="$(control_plane_node)"

delete_namespace_if_exists final

k delete pv final-pv --ignore-not-found >/dev/null 2>&1 || true
k label node "$CP" zone- >/dev/null 2>&1 || true
node_ssh "$CP" \
    "sudo rm -f /var/lib/minikube/etcd-backup/final.db; \
     sudo rm -rf /data/final" >/dev/null 2>&1 || true

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 26 teardown done"
