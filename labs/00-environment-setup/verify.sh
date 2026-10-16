#!/usr/bin/env bash
# Lab 00 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — tools present at pinned versions
check "kubectl installed at $KUBERNETES_VERSION" \
    bash -c "kubectl version --client -o json 2>/dev/null | jq -re '.clientVersion.gitVersion == \"$KUBERNETES_VERSION\"'"
check "helm installed at $HELM_VERSION" \
    bash -c "helm version --short 2>/dev/null | grep -q '^$HELM_VERSION'"
check "kustomize installed at $KUSTOMIZE_VERSION" \
    bash -c "kustomize version 2>/dev/null | grep -q '$KUSTOMIZE_VERSION'"
check "etcdctl installed at $ETCD_VERSION" \
    bash -c "etcdctl version 2>/dev/null | grep -q '${ETCD_VERSION#v}'"

# Task 2 — profile running, node Ready, k8s 1.34, addons
check "minikube profile '$MINIKUBE_PROFILE' running" \
    bash -c "minikube -p $MINIKUBE_PROFILE status -o json 2>/dev/null \
        | jq -e '(if type == \"array\" then .[0] else . end) \
            | .Host==\"Running\" and .APIServer==\"Running\"'"
check "all cluster nodes Ready" all_nodes_ready
check_match "kubernetes server is v1.34.x" \
    "$(k get --raw=/version 2>/dev/null | jq -r .gitVersion)" '^v1\.34\.'
check "calico CNI pods running" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pods -l k8s-app=calico-node --no-headers 2>/dev/null | grep -q Running"
check "metrics-server available" deploy_available kube-system metrics-server
check "ingress-nginx controller available" \
    deploy_available ingress-nginx ingress-nginx-controller

# Task 3 — current context
check_eq "current context is cka-labs" \
    "$(kubectl config current-context 2>/dev/null || true)" "$KUBE_CONTEXT"

# Task 4 — session alias/completion can't be verified from a script (manual step)

# Task 5 — playground namespace with label
check_jsonpath "namespace playground labeled env=learning" \
    namespace/playground '{.metadata.labels.env}' 'learning'

# Task 6 — default namespace on current context
check_eq "context default namespace is playground" \
    "$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)" \
    "playground"

# Task 7 — output files
check_file_contains "nodes.yaml saved" "$OUT_DIR/nodes.yaml" 'kind: +(Node)?List'
check_file_contains "cluster-info.txt saved" "$OUT_DIR/cluster-info.txt" \
    'control plane|running at'

# Task 8 — crictl output saved
check_file_contains "crictl-ps.txt saved" "$OUT_DIR/crictl-ps.txt" 'kube-apiserver'

finish_checks
