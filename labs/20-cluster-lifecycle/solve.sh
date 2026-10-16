#!/usr/bin/env bash
# Lab 20 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

CP="$(control_plane_node)"
KUBEADM="sudo /var/lib/minikube/binaries/${KUBERNETES_VERSION}/kubeadm"

# Task 1 — kubeadm-init prerequisites inside the node: swap state,
# br_netfilter module, ip_forward sysctl
node_ssh "$CP" "sudo swapon --show; sudo lsmod | grep br_netfilter; \
    sudo sysctl net.ipv4.ip_forward" > "$OUT_DIR/infra-prep.txt" 2>&1 \
    || true

# Task 2 — versions from both sides
node_ssh "$CP" "$KUBEADM version -o yaml" > "$OUT_DIR/kubeadm-version.txt"
k version > "$OUT_DIR/kubectl-version.txt"

# Task 3 — bootstrap token lifecycle (tagged so teardown can find it)
node_ssh "$CP" \
    "$KUBEADM token create --ttl 2h --print-join-command \
        --description cka-lab-20" > "$OUT_DIR/join.txt"
node_ssh "$CP" "$KUBEADM token list" > "$OUT_DIR/tokens.txt"
_tok="$(awk '{for(i=1;i<NF;i++) if($i=="--token") print $(i+1)}' \
    "$OUT_DIR/join.txt")"
node_ssh "$CP" "$KUBEADM token delete $_tok" >/dev/null
node_ssh "$CP" "$KUBEADM token list" > "$OUT_DIR/tokens-after-delete.txt"

# Task 4 — certificate expiration check
# minikube keeps its PKI under /var/lib/minikube/certs, not /etc/kubernetes/pki
node_ssh "$CP" \
    "$KUBEADM certs check-expiration --cert-dir /var/lib/minikube/certs" \
    > "$OUT_DIR/certs-expiration.txt"

# Task 5 — upgrade plan (may fail offline; output still recorded) +
# the kubeadm-config ConfigMap
node_ssh "$CP" "$KUBEADM upgrade plan" \
    > "$OUT_DIR/upgrade-plan.txt" 2>&1 || true
k get cm kubeadm-config -n kube-system -o yaml \
    > "$OUT_DIR/kubeadm-config.yaml"

# Task 6 — workload to drain: deploy web (6 replicas) + PDB
k apply -n lifecycle -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 6
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: app
        image: nginx:1.27
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: lifecycle
spec:
  minAvailable: 4
  selector:
    matchLabels: {app: web}
EOF
wait_rollout lifecycle web 240s

# Task 7 — cordon the first worker
k cordon cka-labs-m02 >/dev/null

# Task 8 — drain it (daemonsets + emptyDir need the extra flags)
k drain cka-labs-m02 --ignore-daemonsets --delete-emptydir-data \
    >/dev/null

# Task 9 — record the node's kubelet version (the field a real
# `kubeadm upgrade node` would bump)
k get node cka-labs-m02 \
    -o jsonpath='{.status.nodeInfo.kubeletVersion}' \
    > "$OUT_DIR/kubelet-version.txt"
echo >> "$OUT_DIR/kubelet-version.txt"

# Task 10 — bring the node back
k uncordon cka-labs-m02 >/dev/null

# Task 11 — final node listing
k get nodes -o wide > "$OUT_DIR/nodes-final.txt"

info "lab 20 solved"
