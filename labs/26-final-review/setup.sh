#!/usr/bin/env bash
# Lab 26 setup — seed ns final with a broken `legacy` deployment and a
# pre-created manual PV; stage etcdctl/etcdutl on the node for task 12.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

harden_ingress_nginx
ensure_node_etcd_tools

delete_namespace_if_exists final
ensure_namespace final

# reset leftovers from a previous run
k delete pv final-pv --ignore-not-found >/dev/null 2>&1 || true
k label node "$(control_plane_node)" zone- >/dev/null 2>&1 || true
node_ssh "$(control_plane_node)" \
    "sudo rm -f /var/lib/minikube/etcd-backup/final.db; \
     sudo rm -rf /data/final" >/dev/null 2>&1 || true

k apply -f "$LAB_DIR/manifests/broken-legacy.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/pv.yaml" >/dev/null

info "lab 26 setup done — 'legacy' is broken, 'final-pv' is Available"
