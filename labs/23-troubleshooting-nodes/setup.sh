#!/usr/bin/env bash
# Lab 23 setup — grow to 3 nodes, then BREAK: kubelet stopped on m03,
# m02 cordoned + tainted. Workloads seeded into ns ts-nodes.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

ensure_minikube_nodes 3

# calico-node DaemonSet must cover the new nodes before pods land there
wait_for "calico-node ready on all nodes" 240 \
    bash -c "d=\$(kubectl --context $KUBE_CONTEXT -n kube-system get ds \
        calico-node -o jsonpath='{.status.desiredNumberScheduled}' \
        2>/dev/null); \
        r=\$(kubectl --context $KUBE_CONTEXT -n kube-system get ds \
        calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null); \
        [[ -n \"\$d\" && \"\$d\" == \"\$r\" ]]"

# idempotent reset first: every node alive, schedulable, untainted
for node in cka-labs cka-labs-m02 cka-labs-m03; do
    node_ssh "$node" "sudo systemctl start kubelet" >/dev/null 2>&1 \
        || true
    k uncordon "$node" >/dev/null 2>&1 || true
    k taint node "$node" maintenance:NoSchedule- >/dev/null 2>&1 || true
done
k wait --for=condition=Ready nodes --all --timeout=180s >/dev/null

delete_namespace_if_exists ts-nodes
ensure_namespace ts-nodes
k apply -f "$LAB_DIR/manifests/node-app.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/web.yaml" >/dev/null

# now break things: cordon + taint m02, stop the kubelet on m03
k cordon cka-labs-m02 >/dev/null
k taint node cka-labs-m02 maintenance=true:NoSchedule >/dev/null
node_ssh cka-labs-m03 "sudo systemctl stop kubelet" >/dev/null
info "waiting for cka-labs-m03 to report NotReady (kubelet stopped)..."
wait_for "cka-labs-m03 NotReady" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT get node cka-labs-m03 \
        -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' \
        2>/dev/null | grep -qv True"

info "lab 23 setup done — m03 NotReady, m02 cordoned + tainted"
