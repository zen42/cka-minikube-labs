#!/usr/bin/env bash
# Lab 17 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — base rendered
check_file_contains "base-rendered.yaml has Deployment web" \
    "$OUT_DIR/base-rendered.yaml" 'name: web'

# Task 2 — dev overlay rendered correctly
check_file_contains "dev-rendered.yaml has dev-web" \
    "$OUT_DIR/dev-rendered.yaml" 'dev-web'
check_file_contains "dev-rendered.yaml has LOG_LEVEL" \
    "$OUT_DIR/dev-rendered.yaml" 'LOG_LEVEL'
check_file_contains "dev-rendered.yaml targets kz-dev" \
    "$OUT_DIR/dev-rendered.yaml" 'kz-dev'

# Task 3 — prod overlay rendered correctly
check_file_contains "prod-rendered.yaml has prod-web" \
    "$OUT_DIR/prod-rendered.yaml" 'prod-web'
check_file_contains "prod-rendered.yaml bumps nginx to 1.27" \
    "$OUT_DIR/prod-rendered.yaml" 'nginx:1.27'
check_file_contains "prod-rendered.yaml sets cpu request" \
    "$OUT_DIR/prod-rendered.yaml" '100m'

# Task 5+6 — prod actually applied at 4 replicas with the right spec
check_jsonpath "prod-web runs 4 replicas" \
    deploy/prod-web '{.spec.replicas}' '4' -n kz-prod
check_jsonpath "prod-web image is nginx:1.27" \
    deploy/prod-web '{.spec.template.spec.containers[0].image}' \
    'nginx:1.27' -n kz-prod
check_jsonpath "prod-web pods carry env=prod" \
    deploy/prod-web '{.spec.template.metadata.labels.env}' \
    'prod' -n kz-prod
check_jsonpath "prod-web requests 100m cpu" \
    deploy/prod-web \
    '{.spec.template.spec.containers[0].resources.requests.cpu}' \
    '100m' -n kz-prod
check "prod app-config generated (hashed name)" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kz-prod get cm \
        -o name 2>/dev/null | grep -q '^configmap/prod-app-config-'"
_envfrom="$(k -n kz-prod get deploy prod-web \
    -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}' \
    2>/dev/null || true)"
check_match "prod deployment consumes app-config via envFrom" \
    "$_envfrom" '^prod-app-config-'

# Task 6 — diff output captured
check_file_contains "diff.txt captured the prod-web change" \
    "$OUT_DIR/diff.txt" 'prod-web'

# Task 7 — get -k output saved
check_file_contains "prod-get.txt lists prod-web" \
    "$OUT_DIR/prod-get.txt" 'prod-web'

# Task 8 — dev overlay deleted
check_absent "deployment dev-web deleted" \
    deployment dev-web -n kz-dev
check_fails "no dev-app-config configmap left in kz-dev" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kz-dev get cm \
        -o name 2>/dev/null | grep -q 'dev-app-config-'"

finish_checks
