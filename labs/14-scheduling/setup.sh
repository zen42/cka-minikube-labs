#!/usr/bin/env bash
# Lab 14 setup — grow to 3 nodes, clean leftover labels/taints, seed ns.
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

# remove leftover lab labels/taints/cordons (idempotent reset)
for node in cka-labs cka-labs-m02 cka-labs-m03; do
    k label node "$node" disktype- >/dev/null 2>&1 || true
    k taint node "$node" dedicated:NoSchedule- >/dev/null 2>&1 || true
    k uncordon "$node" >/dev/null 2>&1 || true
done

delete_namespace_if_exists sched
ensure_namespace sched

info "lab 14 setup done — 3 nodes Ready, labels/taints cleaned"
