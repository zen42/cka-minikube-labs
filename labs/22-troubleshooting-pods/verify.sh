#!/usr/bin/env bash
# Lab 22 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — bad image tag fixed
check_jsonpath "img-typo now runs nginx:1.27" \
    deploy/img-typo '{.spec.template.spec.containers[0].image}' \
    'nginx:1.27' -n ts-pods
check "img-typo is available" deploy_available ts-pods img-typo

# Task 2 — crash-app: exit code recorded + pod healthy now
check_file_contains "crash-exit-code.txt records exit code 3" \
    "$OUT_DIR/crash-exit-code.txt" '^3$'
check_jsonpath "crash-app is Running" \
    pod/crash-app '{.status.phase}' 'Running' -n ts-pods
check_jsonpath "crash-app has FOO set" \
    pod/crash-app '{.spec.containers[0].env[0].name}' 'FOO' -n ts-pods

# Task 3 — probe port fixed + rollout actually Ready
check_jsonpath "probe-fail probe hits port 80" \
    deploy/probe-fail \
    '{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' \
    '80' -n ts-pods
check "probe-fail replicas are Ready" \
    deploy_available ts-pods probe-fail

# Task 4 — oom-app: reason + exit code recorded, running under a sane
# limit with a bounded workload
check_file_contains "oom-reason.txt records OOMKilled" \
    "$OUT_DIR/oom-reason.txt" 'OOMKilled'
check_file_contains "oom-reason.txt records exit code 137" \
    "$OUT_DIR/oom-reason.txt" '137'
check_jsonpath "oom-app is Running" \
    pod/oom-app '{.status.phase}' 'Running' -n ts-pods
check_jsonpath "oom-app limit raised to 64Mi" \
    pod/oom-app '{.spec.containers[0].resources.limits.memory}' \
    '64Mi' -n ts-pods

# Task 5 — pending-app: reason recorded + scheduled now
check_file_contains "pending-reason.txt names the scheduling failure" \
    "$OUT_DIR/pending-reason.txt" 'Insufficient'
check_jsonpath "pending-app is Running" \
    pod/pending-app '{.status.phase}' 'Running' -n ts-pods

# Task 6 — missing ConfigMap created; pod self-recovered
check_jsonpath "app-settings has MODE=prod" \
    configmap/app-settings '{.data.MODE}' 'prod' -n ts-pods
check_jsonpath "cm-missing is Running" \
    pod/cm-missing '{.status.phase}' 'Running' -n ts-pods

# Task 7 — ephemeral debug container inside quiet
check_jsonpath "quiet has a busybox ephemeral container" \
    pod/quiet '{.spec.ephemeralContainers[0].image}' \
    'busybox:1.36' -n ts-pods

# Task 8 — node hostname captured; debugger pod gone
check_file_contains "node-hostname.txt has the node name" \
    "$OUT_DIR/node-hostname.txt" 'cka-labs'
check_fails "no node-debugger pod left behind" \
    bash -c "kubectl --context $KUBE_CONTEXT -n default get pods \
        -o name 2>/dev/null | grep -q 'node-debugger'"

# Task 9 — sidecar log captured
check_file_contains "sidecar.log has the error token" \
    "$OUT_DIR/sidecar.log" 'token-7f3a'

# Task 10 — events captured + probe-fail Ready via kubectl wait
check_file_contains "events.txt shows failure events" \
    "$OUT_DIR/events.txt" 'BackOff|Failed|Unhealthy'
check "all probe-fail pods Ready" \
    k wait --for=condition=Ready pod -l app=probe-fail -n ts-pods \
        --timeout=30s

finish_checks
