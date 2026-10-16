#!/usr/bin/env bash
# Lab 00 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — tools green
"$REPO_ROOT/scripts/check-prereqs.sh" >/dev/null || \
    "$REPO_ROOT/scripts/install-tools.sh"
"$REPO_ROOT/scripts/check-prereqs.sh" >/dev/null

# Task 2 — cluster up
"$REPO_ROOT/setup-minikube.sh"
wait_for "node Ready" 300 all_nodes_ready

# Task 3 — current context
kubectl config use-context "$KUBE_CONTEXT" >/dev/null

# Task 4 — exam-style completion (alias only applies to interactive shells)
source <(kubectl completion bash) 2>/dev/null || true

# Task 5 — playground namespace
kubectl --context "$KUBE_CONTEXT" create namespace playground \
    --dry-run=client -o yaml | kubectl --context "$KUBE_CONTEXT" apply -f - >/dev/null
kubectl --context "$KUBE_CONTEXT" label namespace playground env=learning \
    --overwrite >/dev/null

# Task 6 — default namespace for current context
kubectl config set-context --current --namespace=playground >/dev/null

# Task 7 — save cluster info
kubectl --context "$KUBE_CONTEXT" get nodes -o yaml > "$OUT_DIR/nodes.yaml"
kubectl --context "$KUBE_CONTEXT" cluster-info > "$OUT_DIR/cluster-info.txt"

# Task 8 — inside the node
node_ssh "$(control_plane_node)" sudo crictl ps > "$OUT_DIR/crictl-ps.txt"

info "lab 00 solved"
