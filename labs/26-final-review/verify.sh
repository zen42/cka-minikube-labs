#!/usr/bin/env bash
# Lab 26 verify — one or more checks per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
CP="$(control_plane_node)"

# clean up any probe pods left by an interrupted verify
k delete pod v26-allow v26-deny -n final --ignore-not-found --wait=false \
    >/dev/null 2>&1 || true

# Task 1 — shop deployment
check_jsonpath "shop image is nginx:1.27" \
    deploy/shop '{.spec.template.spec.containers[0].image}' \
    'nginx:1.27' -n final
check_jsonpath "shop runs 3 replicas" \
    deploy/shop '{.spec.replicas}' '3' -n final
check_jsonpath "shop cpu request is 50m" \
    deploy/shop \
    '{.spec.template.spec.containers[0].resources.requests.cpu}' \
    '50m' -n final
check_jsonpath "shop memory limit is 128Mi" \
    deploy/shop \
    '{.spec.template.spec.containers[0].resources.limits.memory}' \
    '128Mi' -n final
check_jsonpath "shop pods carry tier=frontend" \
    deploy/shop '{.spec.template.metadata.labels.tier}' \
    'frontend' -n final
check "shop deployment available" deploy_available final shop

# Task 2 — services
check_jsonpath "shop-svc is ClusterIP on 80" \
    svc/shop-svc '{.spec.ports[0].port}' '80' -n final
check_jsonpath "shop-np publishes nodePort 30080" \
    svc/shop-np '{.spec.ports[0].nodePort}' '30080' -n final

# Task 3 — ingress
check_jsonpath "shop-ing routes to shop-svc" \
    ingress/shop-ing \
    '{.spec.rules[0].http.paths[0].backend.service.name}' \
    'shop-svc' -n final
check_match "ingress serves shop.final.local" \
    "$(probe_http http://ingress-nginx-controller.ingress-nginx \
        'Host: shop.final.local' 2>/dev/null || true)" 'nginx'

# Task 4 — HPA
check_jsonpath "hpa shop min 2" hpa/shop '{.spec.minReplicas}' '2' -n final
check_jsonpath "hpa shop max 5" hpa/shop '{.spec.maxReplicas}' '5' -n final
check_jsonpath "hpa targets 60% cpu" hpa/shop \
    '{.spec.metrics[0].resource.target.averageUtilization}' '60' -n final

# Task 5 — config via envFrom
check_jsonpath "shop-config carries THEME=dark" \
    cm/shop-config '{.data.THEME}' 'dark' -n final
check_resource "shop-secret exists" secret shop-secret -n final
check_eq "THEME is set inside a shop pod" \
    "$(k exec deploy/shop -n final -- printenv THEME 2>/dev/null \
        || true)" 'dark'
check_eq "API_KEY is set inside a shop pod" \
    "$(k exec deploy/shop -n final -- printenv API_KEY 2>/dev/null \
        || true)" 'abc123'

# Task 6 — storage
check_jsonpath "final-pvc is Bound" pvc/final-pvc '{.status.phase}' \
    'Bound' -n final
check_jsonpath "final-pv is bound to the claim" \
    pv/final-pv '{.spec.claimRef.name}' 'final-pvc'
check "writer pod is Running" \
    bash -c "kubectl --context $KUBE_CONTEXT -n final get pod writer \
        -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Running"
check "writer wrote its hostname to the PV" \
    bash -c "kubectl --context $KUBE_CONTEXT -n final exec writer -- \
        test -s /data/out.txt 2>/dev/null"

# Task 7 — RBAC
check_resource "serviceaccount deployer" serviceaccount deployer -n final
check_resource "role deploy-manager" role deploy-manager -n final
check_resource "rolebinding deploy-manager" rolebinding deploy-manager \
    -n final
check_eq "deployer CAN create deployments" \
    "$(k auth can-i create deployments \
        --as=system:serviceaccount:final:deployer -n final 2>/dev/null \
        || true)" 'yes'
check_eq "deployer CANNOT delete deployments" \
    "$(k auth can-i delete deployments \
        --as=system:serviceaccount:final:deployer -n final 2>/dev/null \
        || true)" 'no'

# Task 8 — NetworkPolicy
check_jsonpath "netpol selects tier=frontend" \
    networkpolicy/shop-allow-ingress-only \
    '{.spec.podSelector.matchLabels.tier}' 'frontend' -n final
check "netpol allows the ingress-nginx namespace" \
    bash -c "kubectl --context $KUBE_CONTEXT -n final get netpol \
        shop-allow-ingress-only -o yaml | grep -q ingress-nginx"
check "access=shop pod CAN reach shop-svc" \
    bash -c "kubectl --context $KUBE_CONTEXT run v26-allow -n final \
        --image=busybox:1.36 --restart=Never --rm -i --quiet \
        --labels access=shop -- \
        wget -qO- -T 5 http://shop-svc | grep -q nginx"
check_fails "unlabelled pod CANNOT reach shop-svc" \
    bash -c "kubectl --context $KUBE_CONTEXT run v26-deny -n final \
        --image=busybox:1.36 --restart=Never --rm -i --quiet -- \
        wget -qO- -T 5 http://shop-svc"
k delete pod v26-allow v26-deny -n final --ignore-not-found --wait=false \
    >/dev/null 2>&1 || true

# Task 9 — CronJob
check_jsonpath "report runs every 10 min" cronjob/report \
    '{.spec.schedule}' '*/10 * * * *' -n final
check_jsonpath "report keeps 2 successful jobs" cronjob/report \
    '{.spec.successfulJobsHistoryLimit}' '2' -n final
check "report-manual job completed" \
    bash -c "kubectl --context $KUBE_CONTEXT -n final get job \
        report-manual -o jsonpath='{.status.conditions[*].type}' \
        2>/dev/null | grep -qw Complete"

# Task 10 — legacy fixed
check_jsonpath "legacy image is httpd:2.4" \
    deploy/legacy '{.spec.template.spec.containers[0].image}' \
    'httpd:2.4' -n final
check "legacy deployment available" deploy_available final legacy

# Task 11 — node scheduling
check_jsonpath "node carries zone=a" "node/$CP" \
    '{.metadata.labels.zone}' 'a'
check_jsonpath "shop pins nodeSelector zone=a" \
    deploy/shop '{.spec.template.spec.nodeSelector.zone}' 'a' -n final

# Task 12 — etcd + inventory
check_file_contains "etcd-status.txt has snapshot stats" \
    "$OUT_DIR/etcd-status.txt" 'REVISION|TOTAL'
check_file_contains "final-state.txt lists the shop deployment" \
    "$OUT_DIR/final-state.txt" 'deployment.apps/shop'

finish_checks
