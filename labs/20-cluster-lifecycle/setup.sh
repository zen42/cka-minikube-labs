#!/usr/bin/env bash
# Lab 20 setup — grow to 3 nodes, uncordon everyone, clean lab tokens,
# seed ns lifecycle.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

CP="$(control_plane_node)"
KUBEADM="sudo /var/lib/minikube/binaries/${KUBERNETES_VERSION}/kubeadm"

ensure_minikube_nodes 3

# calico-node DaemonSet must cover the new nodes before pods land there
wait_for "calico-node ready on all nodes" 240 \
    bash -c "d=\$(kubectl --context $KUBE_CONTEXT -n kube-system get ds \
        calico-node -o jsonpath='{.status.desiredNumberScheduled}' \
        2>/dev/null); \
        r=\$(kubectl --context $KUBE_CONTEXT -n kube-system get ds \
        calico-node -o jsonpath='{.status.numberReady}' 2>/dev/null); \
        [[ -n \"\$d\" && \"\$d\" == \"\$r\" ]]"

# idempotent reset: uncordon every node, drop leftover lab tokens
for node in cka-labs cka-labs-m02 cka-labs-m03; do
    k uncordon "$node" >/dev/null 2>&1 || true
done
node_ssh "$CP" "$KUBEADM token list 2>/dev/null" \
    | awk 'NR>1 && $0 ~ /cka-lab-20/ {print $1}' \
    | while read -r tok; do
        [[ -n "$tok" ]] && node_ssh "$CP" \
            "$KUBEADM token delete $tok" >/dev/null 2>&1 || true
    done

delete_namespace_if_exists lifecycle
ensure_namespace lifecycle

info "lab 20 setup done — 3 nodes Ready and schedulable"
