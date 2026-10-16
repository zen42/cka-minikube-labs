#!/usr/bin/env bash
# Lab 10 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — pod-reader role
check_resource "role pod-reader exists" role pod-reader -n rbac
check_jsonpath "pod-reader rules cover pods" \
    role/pod-reader '{.rules[0].resources[0]}' 'pods' -n rbac

# Task 2 — jane bound to pod-reader
check_jsonpath "jane-pod-reader points at pod-reader" \
    rolebinding/jane-pod-reader '{.roleRef.name}' 'pod-reader' -n rbac
check_jsonpath "jane-pod-reader subject is jane" \
    rolebinding/jane-pod-reader '{.subjects[0].name}' 'jane' -n rbac

# Task 3 — can-i.txt: yes then no
check_eq "can-i.txt line 1 is yes" \
    "$(sed -n '1p' "$OUT_DIR/can-i.txt" 2>/dev/null | tr -d '[:space:]')" "yes"
check_eq "can-i.txt line 2 is no" \
    "$(sed -n '2p' "$OUT_DIR/can-i.txt" 2>/dev/null | tr -d '[:space:]')" "no"

# Task 4 — node-viewer + ops group
check_resource "clusterrole node-viewer exists" clusterrole node-viewer
check_jsonpath "ops-node-viewer binds group ops" \
    clusterrolebinding/ops-node-viewer '{.subjects[0].name}' 'ops'
check_eq "ops group can list nodes" \
    "$(k auth can-i list nodes --as=someone --as-group=ops 2>/dev/null)" "yes"

# Task 5 — ClusterRole via RoleBinding in default
check_jsonpath "jane-ns-pods roleRef is a ClusterRole" \
    rolebinding/jane-ns-pods '{.roleRef.kind}' 'ClusterRole' -n default
check_eq "jane can list pods in default" \
    "$(k auth can-i list pods -n default --as jane 2>/dev/null)" "yes"
check_eq "jane cannot list pods in kube-system" \
    "$(k auth can-i list pods -n kube-system --as jane 2>/dev/null)" "no"

# Task 6 — dev-can-view fixed
check_jsonpath "dev-can-view now points at pod-reader" \
    rolebinding/dev-can-view '{.roleRef.name}' 'pod-reader' -n rbac
check_jsonpath "dev-can-view subject is dave" \
    rolebinding/dev-can-view '{.subjects[0].name}' 'dave' -n rbac
check_eq "dave can get pods in rbac" \
    "$(k auth can-i get pods -n rbac --as dave 2>/dev/null)" "yes"

# Task 7 — CSR approved + issued
check_jsonpath "csr jane is Approved" \
    csr/jane '{.status.conditions[?(@.type=="Approved")].status}' 'True'
check "csr jane has an issued certificate" \
    bash -c "kubectl --context $KUBE_CONTEXT get csr jane \
        -o jsonpath='{.status.certificate}' 2>/dev/null | grep -q ."

# Task 8 — jane.kubeconfig works
JCFG="$OUT_DIR/jane.kubeconfig"
check "jane kubeconfig can get pods" \
    kubectl --kubeconfig "$JCFG" get pods --request-timeout=10s
_who="$(kubectl --kubeconfig "$JCFG" auth whoami \
    --request-timeout=10s 2>/dev/null || true)"
check_match "whoami reports user jane" "$_who" 'jane'
check_match "whoami reports group developers" "$_who" 'developers'
check_fails "jane kubeconfig cannot get nodes" \
    kubectl --kubeconfig "$JCFG" get nodes --request-timeout=10s

# Task 9 — jane-perms.txt lists pods
check_file_contains "jane-perms.txt lists pods" \
    "$OUT_DIR/jane-perms.txt" 'pods'

# Task 10 — aggregation
check_jsonpath "monitoring-endpoints carries the aggregate label" \
    clusterrole/monitoring-endpoints \
    '{.metadata.labels.rbac\.example\.com/aggregate-to-monitoring}' 'true'
check "monitoring aggregated services into its rules" \
    bash -c "kubectl --context $KUBE_CONTEXT get clusterrole monitoring \
        -o jsonpath='{.rules[*].resources}' 2>/dev/null \
        | grep -qw services"

finish_checks
