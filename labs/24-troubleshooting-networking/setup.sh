#!/usr/bin/env bash
# Lab 24 setup — harden ingress-nginx, seed ns ts-net with healthy pods
# and a stack of broken plumbing (service selector, targetPort, netpol,
# ingress backend), then kill DNS by scaling coredns to 0.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

harden_ingress_nginx

delete_namespace_if_exists ts-net
ensure_namespace ts-net

k apply -f "$LAB_DIR/manifests/pods.yaml" >/dev/null
for p in web api db client other; do
    wait_pod_ready ts-net "$p" 120s
done

k apply -f "$LAB_DIR/manifests/broken-svc.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/netpol.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/ingress.yaml" >/dev/null

# kill cluster DNS last, after the pods are up — back up the
# deployment first (never overwrite an existing backup)
if [[ ! -f "$STATE_DIR/lab24-coredns.json" ]]; then
    backup_object deployment coredns kube-system \
        "$STATE_DIR/lab24-coredns.json"
fi
k -n kube-system scale deployment coredns --replicas=0 >/dev/null
wait_for "coredns pods gone" 60 \
    bash -c "! kubectl --context $KUBE_CONTEXT -n kube-system get pods \
        -l k8s-app=kube-dns -o name 2>/dev/null | grep -q ."

info "lab 24 setup done — pods healthy, plumbing broken, DNS dead"
