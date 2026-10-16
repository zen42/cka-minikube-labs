#!/usr/bin/env bash
# Lab 15 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — top-nodes.txt
check_file_contains "top-nodes.txt lists cka-labs" \
    "$OUT_DIR/top-nodes.txt" 'cka-labs'
check_file_contains "top-nodes.txt has Mi values" \
    "$OUT_DIR/top-nodes.txt" 'Mi'

# Task 2 — deployment spec + service
check_jsonpath "php-apache requests cpu 200m" \
    deploy/php-apache \
    '{.spec.template.spec.containers[0].resources.requests.cpu}' '200m' \
    -n autoscale
check_jsonpath "php-apache limits cpu 500m" \
    deploy/php-apache \
    '{.spec.template.spec.containers[0].resources.limits.cpu}' '500m' \
    -n autoscale
check_jsonpath "php-apache service exposes 80" \
    service/php-apache '{.spec.ports[0].port}' '80' -n autoscale

# Task 3 — HPA spec
check_jsonpath "hpa targets php-apache" \
    hpa/php-apache '{.spec.scaleTargetRef.name}' 'php-apache' -n autoscale
check_jsonpath "hpa min is 1" \
    hpa/php-apache '{.spec.minReplicas}' '1' -n autoscale
check_jsonpath "hpa max is 5" \
    hpa/php-apache '{.spec.maxReplicas}' '5' -n autoscale
check_jsonpath "hpa cpu target is 50" \
    hpa/php-apache \
    '{.spec.metrics[0].resource.target.averageUtilization}' '50' \
    -n autoscale

# Task 4 — load deploy + HPA actually scaled out (poll — metrics lag).
# Task 10 scales `load` to 0, so if it is already down accept scale-out
# EVIDENCE instead: replicas >= 2 or a SuccessfulRescale event.
check_resource "load generator deployment exists" \
    deployment load -n autoscale
_load_replicas="$(k get deploy load -n autoscale \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
if [[ "${_load_replicas:-0}" != "0" ]]; then
    wait_for "hpa scaled out" 300 \
        bash -c "kubectl --context $KUBE_CONTEXT -n autoscale get hpa \
            php-apache -o jsonpath='{.status.desiredReplicas}' 2>/dev/null \
            | grep -qE '^[2-9]'" || true
fi
_des="$(k get hpa php-apache -n autoscale \
    -o jsonpath='{.status.desiredReplicas}' 2>/dev/null || true)"
_cur="$(k get hpa php-apache -n autoscale \
    -o jsonpath='{.status.currentReplicas}' 2>/dev/null || true)"
_rescale="$(k get events -n autoscale \
    --field-selector involvedObject.kind=HorizontalPodAutoscaler,involvedObject.name=php-apache,reason=SuccessfulRescale \
    -o name 2>/dev/null || true)"
check "hpa scaled php-apache above 1 replica" \
    test "${_cur:-0}" -ge 2 -o "${_des:-0}" -ge 2 -o -n "$_rescale"

# Task 5 — top-pods.txt
check_file_contains "top-pods.txt lists php-apache" \
    "$OUT_DIR/top-pods.txt" 'php-apache'

# Task 6 — QoS classes
check_jsonpath "qos-guaranteed class" \
    pod/qos-guaranteed '{.status.qosClass}' 'Guaranteed' -n autoscale
check_jsonpath "qos-burstable class" \
    pod/qos-burstable '{.status.qosClass}' 'Burstable' -n autoscale
check_jsonpath "qos-besteffort class" \
    pod/qos-besteffort '{.status.qosClass}' 'BestEffort' -n autoscale
check_file_contains "qos.txt records qos-guaranteed" \
    "$OUT_DIR/qos.txt" 'qos-guaranteed=Guaranteed'
check_file_contains "qos.txt records qos-burstable" \
    "$OUT_DIR/qos.txt" 'qos-burstable=Burstable'
check_file_contains "qos.txt records qos-besteffort" \
    "$OUT_DIR/qos.txt" 'qos-besteffort=BestEffort'

# Task 7 — LimitRange spec + injection into no-resources
check_jsonpath "limitrange default cpu is 200m" \
    limitrange/defaults '{.spec.limits[0].default.cpu}' '200m' -n autoscale
check_jsonpath "limitrange default request cpu is 100m" \
    limitrange/defaults '{.spec.limits[0].defaultRequest.cpu}' '100m' \
    -n autoscale
check_jsonpath "no-resources got injected requests" \
    pod/no-resources \
    '{.spec.containers[0].resources.requests.cpu}' '100m' -n autoscale

# Task 8 — ResourceQuota spec + accounting
check_jsonpath "team-quota caps pods at 15" \
    resourcequota/team-quota '{.spec.hard.pods}' '15' -n autoscale
check_jsonpath "team-quota caps requests.cpu at 2" \
    resourcequota/team-quota '{.spec.hard.requests\.cpu}' '2' -n autoscale
_used="$(k get resourcequota team-quota -n autoscale \
    -o jsonpath='{.status.used.pods}' 2>/dev/null || echo 0)"
check "team-quota is counting pods" test "${_used:-0}" -gt 0

# Task 9 — cache-hpa v2 spec
check_jsonpath "cache-hpa targets cache" \
    hpa/cache-hpa '{.spec.scaleTargetRef.name}' 'cache' -n autoscale
check_jsonpath "cache-hpa uses memory utilization" \
    hpa/cache-hpa '{.spec.metrics[0].resource.name}' 'memory' -n autoscale
check_jsonpath "cache-hpa memory target is 70" \
    hpa/cache-hpa \
    '{.spec.metrics[0].resource.target.averageUtilization}' '70' \
    -n autoscale
check_jsonpath "cache-hpa scale-down window is 60s" \
    hpa/cache-hpa \
    '{.spec.behavior.scaleDown.stabilizationWindowSeconds}' '60' \
    -n autoscale

# Task 10 — load at 0; hpa.txt saved
check_jsonpath "load scaled to 0" \
    deploy/load '{.spec.replicas}' '0' -n autoscale
check_file_contains "hpa.txt lists php-apache" \
    "$OUT_DIR/hpa.txt" 'php-apache'

finish_checks
