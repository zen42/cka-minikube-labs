#!/usr/bin/env bash
# Lab 10 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — Role pod-reader
k create role pod-reader -n rbac \
    --verb=get,list,watch --resource=pods 2>/dev/null \
    || k get role pod-reader -n rbac >/dev/null

# Task 2 — RoleBinding jane-pod-reader
k create rolebinding jane-pod-reader -n rbac \
    --role=pod-reader --user=jane 2>/dev/null \
    || k get rolebinding jane-pod-reader -n rbac >/dev/null

# Task 3 — can-i answers to file
printf '%s\n%s\n' \
    "$(k auth can-i get pods -n rbac --as jane)" \
    "$(k auth can-i create deployments -n rbac --as jane)" \
    > "$OUT_DIR/can-i.txt"

# Task 4 — ClusterRole node-viewer + binding to group ops
k create clusterrole node-viewer \
    --verb=get,list,watch --resource=nodes 2>/dev/null \
    || k get clusterrole node-viewer >/dev/null
k create clusterrolebinding ops-node-viewer \
    --clusterrole=node-viewer --group=ops 2>/dev/null \
    || k get clusterrolebinding ops-node-viewer >/dev/null
[[ "$(k auth can-i list nodes --as=someone --as-group=ops)" == "yes" ]]

# Task 5 — ClusterRole bound via RoleBinding in 'default'
k create clusterrole ns-pod-reader \
    --verb=get,list --resource=pods 2>/dev/null \
    || k get clusterrole ns-pod-reader >/dev/null
k create rolebinding jane-ns-pods -n default \
    --clusterrole=ns-pod-reader --user=jane 2>/dev/null \
    || k get rolebinding jane-ns-pods -n default >/dev/null
[[ "$(k auth can-i list pods -n default --as jane)" == "yes" ]]
[[ "$(k auth can-i list pods -n kube-system --as jane)" == "no" ]]

# Task 6 — fix dev-can-view: roleRef is immutable → delete + recreate
k delete rolebinding dev-can-view -n rbac >/dev/null
k create rolebinding dev-can-view -n rbac \
    --role=pod-reader --user=dave >/dev/null
[[ "$(k auth can-i get pods -n rbac --as dave)" == "yes" ]]

# Task 7 — certificate-based user jane
openssl genrsa -out "$OUT_DIR/jane.key" 2048 >/dev/null 2>&1
openssl req -new -key "$OUT_DIR/jane.key" -out "$OUT_DIR/jane.csr" \
    -subj '/CN=jane/O=developers' >/dev/null 2>&1
k delete csr jane --ignore-not-found --wait=true >/dev/null 2>&1 || true
k apply -f - >/dev/null <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  signerName: kubernetes.io/kube-apiserver-client
  usages: [client auth]
  expirationSeconds: 86400
  request: $(base64 -w0 "$OUT_DIR/jane.csr")
EOF
k certificate approve jane >/dev/null
wait_for "csr jane issued" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT get csr jane \
        -o jsonpath='{.status.certificate}' 2>/dev/null | grep -q ."
k get csr jane -o jsonpath='{.status.certificate}' | base64 -d \
    > "$OUT_DIR/jane.crt"

# Task 8 — jane.kubeconfig (own ~/.kube/config untouched)
# minikube's kubeconfig keeps the CA as a FILE path (certificate-authority);
# clusters that embed it have certificate-authority-data — handle either.
JCFG="$OUT_DIR/jane.kubeconfig"
rm -f "$JCFG"
SERVER="$(k config view --minify --raw \
    -o jsonpath='{.clusters[0].cluster.server}')"
CA_FILE="$(k config view --minify --raw \
    -o jsonpath='{.clusters[0].cluster.certificate-authority}')"
if [[ -z "$CA_FILE" ]]; then
    CA_FILE="$OUT_DIR/ca.crt"
    k config view --minify --raw \
        -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
        | base64 -d > "$CA_FILE"
fi
kubectl --kubeconfig "$JCFG" config set-cluster cka-labs \
    --server="$SERVER" --certificate-authority="$CA_FILE" \
    --embed-certs=true >/dev/null
kubectl --kubeconfig "$JCFG" config set-credentials jane \
    --client-certificate="$OUT_DIR/jane.crt" \
    --client-key="$OUT_DIR/jane.key" \
    --embed-certs=true >/dev/null
kubectl --kubeconfig "$JCFG" config set-context jane@cka-labs \
    --cluster=cka-labs --user=jane --namespace=rbac >/dev/null
kubectl --kubeconfig "$JCFG" config use-context jane@cka-labs >/dev/null
kubectl --kubeconfig "$JCFG" get pods >/dev/null
kubectl --kubeconfig "$JCFG" auth whoami | grep -q 'jane'

# Task 9 — jane's permission listing
k auth can-i --list --as jane -n rbac > "$OUT_DIR/jane-perms.txt"

# Task 10 — aggregated ClusterRoles
k apply -f - >/dev/null <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-endpoints
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: [endpoints, services]
  verbs: [get, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: []
EOF
# the aggregation controller fills .rules asynchronously — wait for it
wait_for "monitoring aggregates services rule" 90 \
    bash -c "kubectl --context $KUBE_CONTEXT get clusterrole monitoring \
        -o jsonpath='{.rules[*].resources}' 2>/dev/null | grep -qw services"

info "lab 10 solved"
