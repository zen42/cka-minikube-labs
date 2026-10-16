#!/usr/bin/env bash
# Lab 20 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

CP="$(control_plane_node)"
KUBEADM="sudo /var/lib/minikube/binaries/${KUBERNETES_VERSION}/kubeadm"

# Task 1 — infra-prep inspection recorded
check_file_contains "infra-prep.txt shows ip_forward enabled" \
    "$OUT_DIR/infra-prep.txt" 'ip_forward = 1'

# Task 2 — version files
check_file_contains "kubeadm-version.txt reports v1.34" \
    "$OUT_DIR/kubeadm-version.txt" 'gitVersion: v1\.34'
check_file_contains "kubectl-version.txt reports the server" \
    "$OUT_DIR/kubectl-version.txt" 'Server Version'

# Task 3 — join command captured + token was deleted again
check_file_contains "join.txt holds a kubeadm join command" \
    "$OUT_DIR/join.txt" 'kubeadm join'
check_file_contains "tokens.txt lists bootstrap tokens" \
    "$OUT_DIR/tokens.txt" 'TOKEN'
_tok="$(awk '{for(i=1;i<NF;i++) if($i=="--token") print $(i+1)}' \
    "$OUT_DIR/join.txt" 2>/dev/null || true)"
if [[ -n "$_tok" ]]; then
    check_fails "lab token $_tok was deleted" \
        bash -c "minikube -p $MINIKUBE_PROFILE ssh -- \
            '$KUBEADM token list' 2>/dev/null | grep -q '$_tok'"
else
    fail "join.txt has no --token to check deletion for"
fi

# Task 4 — cert expiration recorded
check_file_contains "certs-expiration.txt covers apiserver" \
    "$OUT_DIR/certs-expiration.txt" 'apiserver'

# Task 5 — upgrade plan output + kubeadm-config
check "upgrade-plan.txt is non-empty" \
    test -s "$OUT_DIR/upgrade-plan.txt"
check_file_contains "kubeadm-config.yaml pins kubernetesVersion v1.34" \
    "$OUT_DIR/kubeadm-config.yaml" 'kubernetesVersion: v1\.34'

# Task 6 — workload + PDB
check_jsonpath "web runs 6 replicas" \
    deploy/web '{.spec.replicas}' '6' -n lifecycle
check_jsonpath "web-pdb keeps 4 available" \
    pdb/web-pdb '{.spec.minAvailable}' '4' -n lifecycle

# Task 7/8 — drained state was reached; the web pods left m02
check_fails "no lifecycle pods remain on cka-labs-m02" \
    bash -c "kubectl --context $KUBE_CONTEXT -n lifecycle get pods \
        -o wide 2>/dev/null | grep -q 'cka-labs-m02'"

# Task 9 — kubelet version recorded
check_file_contains "kubelet-version.txt records v1.34" \
    "$OUT_DIR/kubelet-version.txt" 'v1\.34'

# Task 10 — node is schedulable again
_unsched="$(k get node cka-labs-m02 \
    -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)"
check_eq "cka-labs-m02 is schedulable" "$_unsched" ""
wait_for "web back to 6 ready replicas" 240 \
    bash -c "kubectl --context $KUBE_CONTEXT -n lifecycle get deploy web \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null \
        | grep -qE '^6$'" || true

# Task 11 — final listing
check_file_contains "nodes-final.txt lists all 3 nodes Ready" \
    "$OUT_DIR/nodes-final.txt" 'cka-labs-m02'
check_file_contains "nodes-final.txt lists cka-labs-m03" \
    "$OUT_DIR/nodes-final.txt" 'cka-labs-m03'

finish_checks
