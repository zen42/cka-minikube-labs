#!/usr/bin/env bash
# Lab 01 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — namespace basics exists
check_resource "namespace basics exists" namespace basics

# Task 2 — restart-policy.txt has the field path
check_file_contains "restart-policy.txt contains the field path" \
    "$OUT_DIR/restart-policy.txt" '(pod\.)?spec\.restartPolicy'

# Task 3 — pod.yaml has kind: Pod; pod nginx-pod Running, image, label
check_file_contains "pod.yaml is a Pod manifest" "$OUT_DIR/pod.yaml" 'kind: +Pod'
check_eq "pod nginx-pod Running" "$(pod_phase basics nginx-pod)" "Running"
check_jsonpath "nginx-pod image is nginx:1.27" \
    pod/nginx-pod '{.spec.containers[0].image}' 'nginx:1.27' -n basics
check_jsonpath "nginx-pod has label tier=web" \
    pod/nginx-pod '{.metadata.labels.tier}' 'web' -n basics

# Task 4 — deployment web exists and is available (>=2 ready; scaled to 3 in task 6)
check_resource "deployment web exists" deployment web -n basics
check "deployment web has >=2 available replicas" \
    bash -c "[ \"\$(kubectl --context $KUBE_CONTEXT -n basics get deploy web -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)\" -ge 2 ]"

# Task 5 — label + annotation on deployment web
check_jsonpath "web labeled app.kubernetes.io/part-of=shop" \
    deployment/web '{.metadata.labels.app\.kubernetes\.io/part-of}' 'shop' -n basics
check_jsonpath "web annotated owner=platform-team" \
    deployment/web '{.metadata.annotations.owner}' 'platform-team' -n basics

# Task 6 — replicas patched to 3
check_jsonpath "web spec.replicas is 3" \
    deployment/web '{.spec.replicas}' '3' -n basics
check_jsonpath "web has 3 available replicas" \
    deployment/web '{.status.availableReplicas}' '3' -n basics

# Task 7 — revisionHistoryLimit 5
check_jsonpath "web revisionHistoryLimit is 5" \
    deployment/web '{.spec.revisionHistoryLimit}' '5' -n basics

# Task 8 — kubernetes-svc-ip.txt matches actual ClusterIP
check_eq "kubernetes-svc-ip.txt matches the real ClusterIP" \
    "$(cat "$OUT_DIR/kubernetes-svc-ip.txt" 2>/dev/null | tr -d '[:space:]')" \
    "$(k -n default get svc kubernetes -o jsonpath='{.spec.clusterIP}' 2>/dev/null)"

# Task 9 — kube-system-pods.txt: header + >=5 data lines
check_file_contains "kube-system-pods.txt has NAME/NODE header" \
    "$OUT_DIR/kube-system-pods.txt" '^NAME +NODE'
check ">=5 kube-system pods listed" \
    bash -c "test \$(tail -n +2 '$OUT_DIR/kube-system-pods.txt' 2>/dev/null | grep -c .) -ge 5"

# Task 10 — apps-resources.txt lists namespaced apps resources
check_file_contains "apps-resources.txt lists deployments.apps" \
    "$OUT_DIR/apps-resources.txt" '^deployments\.apps$'
check_file_contains "apps-resources.txt lists statefulsets.apps" \
    "$OUT_DIR/apps-resources.txt" '^statefulsets\.apps$'

# Task 11 — cleanup-me gone
check_absent "namespace cleanup-me deleted" namespace cleanup-me

# Task 12 — basics-all.txt captured
check_file_contains "basics-all.txt lists deployment web" \
    "$OUT_DIR/basics-all.txt" 'deployment\.apps/web'

finish_checks
