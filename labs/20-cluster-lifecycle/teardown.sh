#!/usr/bin/env bash
# Lab 20 teardown — remove lab 20 resources; nodes and cluster stay.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

CP="$(control_plane_node)"
KUBEADM="sudo /var/lib/minikube/binaries/${KUBERNETES_VERSION}/kubeadm"

for node in cka-labs cka-labs-m02 cka-labs-m03; do
    k uncordon "$node" >/dev/null 2>&1 || true
done

# sweep any bootstrap tokens this lab created (description cka-lab-20)
node_ssh "$CP" "$KUBEADM token list 2>/dev/null" 2>/dev/null \
    | awk 'NR>1 && $0 ~ /cka-lab-20/ {print $1}' \
    | while read -r tok; do
        [[ -n "$tok" ]] && node_ssh "$CP" \
            "$KUBEADM token delete $tok" >/dev/null 2>&1 || true
    done

delete_namespace_if_exists lifecycle

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 20 teardown done (worker nodes remain — 'make reset-cluster' shrinks)"
