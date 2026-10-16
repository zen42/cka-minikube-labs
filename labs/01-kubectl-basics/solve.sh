#!/usr/bin/env bash
# Lab 01 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — namespace basics
k create namespace basics --dry-run=client -o yaml | k apply -f - >/dev/null
k label namespace basics "cka-lab=$LAB_ID" --overwrite >/dev/null

# Task 2 — explain restartPolicy
k explain pod.spec.restartPolicy >/dev/null
echo "pod.spec.restartPolicy" > "$OUT_DIR/restart-policy.txt"

# Task 3 — generate manifest, add label, apply
k run nginx-pod --image=nginx:1.27 -n basics \
    --dry-run=client -o yaml > "$OUT_DIR/pod.yaml"
k label -f "$OUT_DIR/pod.yaml" tier=web --local -o yaml \
    > "$OUT_DIR/.pod-labeled.yaml" && mv "$OUT_DIR/.pod-labeled.yaml" "$OUT_DIR/pod.yaml"
k apply -f "$OUT_DIR/pod.yaml" >/dev/null
wait_pod_ready basics nginx-pod 120s

# Task 4 — deployment web, 2 replicas
k create deployment web --image=nginx:1.27 --replicas=2 -n basics \
    --dry-run=client -o yaml | k apply -f - >/dev/null
wait_rollout basics web 120s

# Task 5 — label + annotate
k label deployment web app.kubernetes.io/part-of=shop -n basics --overwrite >/dev/null
k annotate deployment web owner=platform-team -n basics --overwrite >/dev/null

# Task 6 — patch to 3 replicas
k patch deployment web -n basics -p '{"spec":{"replicas":3}}' >/dev/null
wait_rollout basics web 120s

# Task 7 — revisionHistoryLimit 5
k patch deployment web -n basics \
    --type=merge -p '{"spec":{"revisionHistoryLimit":5}}' >/dev/null

# Task 8 — ClusterIP of service kubernetes
k -n default get svc kubernetes \
    -o jsonpath='{.spec.clusterIP}' > "$OUT_DIR/kubernetes-svc-ip.txt"

# Task 9 — kube-system pods, custom columns sorted
k -n kube-system get pods \
    -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName \
    --sort-by=.metadata.name > "$OUT_DIR/kube-system-pods.txt"

# Task 10 — namespaced resources in group apps
k api-resources --namespaced=true --api-group=apps -o name \
    > "$OUT_DIR/apps-resources.txt"

# Task 11 — delete old-app, then the namespace
k delete deployment old-app -n cleanup-me --ignore-not-found >/dev/null
k delete namespace cleanup-me --ignore-not-found >/dev/null
wait_for "namespace cleanup-me gone" 60 \
    bash -c "! kubectl --context $KUBE_CONTEXT get ns cleanup-me >/dev/null 2>&1"

# Task 12 — get all in basics
k get all -n basics -o wide > "$OUT_DIR/basics-all.txt"

info "lab 01 solved"
