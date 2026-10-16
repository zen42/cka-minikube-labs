#!/usr/bin/env bash
# Lab 03 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — CM exists, reader healthy
check_jsonpath "app-config has APP_MODE=production" \
    configmap/app-config '{.data.APP_MODE}' 'production' -n config
check_jsonpath "reader has 2 available replicas" \
    deployment/reader '{.status.availableReplicas}' '2' -n config

# Task 2 — app-props from file
check "app-props holds the app.properties content" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config get cm app-props \
        -o jsonpath='{.data.app\.properties}' | grep -q 'color=blue'"

# Task 3 — db-creds decoded values
check_eq "db-creds username is admin" \
    "$(k get secret db-creds -n config -o jsonpath='{.data.username}' \
        2>/dev/null | base64 -d 2>/dev/null || true)" "admin"
check_eq "db-creds password is S3cr3t!" \
    "$(k get secret db-creds -n config -o jsonpath='{.data.password}' \
        2>/dev/null | base64 -d 2>/dev/null || true)" 'S3cr3t!'

# Task 4 — TLS secret
check_jsonpath "web-tls type is kubernetes.io/tls" \
    secret/web-tls '{.type}' 'kubernetes.io/tls' -n config
check "web-tls has tls.crt and tls.key" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config get secret web-tls \
        -o jsonpath='{.data}' | jq -e 'has(\"tls.crt\") and has(\"tls.key\")'"
check "web-tls cert subject is web.example.com" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config get secret web-tls \
        -o jsonpath='{.data.tls\.crt}' | base64 -d \
        | openssl x509 -noout -subject 2>/dev/null | grep -q web.example.com"

# Task 5 — docker-registry secret
check_jsonpath "regcred type is kubernetes.io/dockerconfigjson" \
    secret/regcred '{.type}' 'kubernetes.io/dockerconfigjson' -n config
check "regcred points at registry.example.com" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config get secret regcred \
        -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d \
        | grep -q registry.example.com"

# Task 6 — env-pod env vars
check "env-pod has MODE=production" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config exec env-pod -- env \
        | grep -q '^MODE=production$'"
check "env-pod has DB_PASSWORD=S3cr3t!" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config exec env-pod -- env \
        | grep -q '^DB_PASSWORD=S3cr3t!$'"

# Task 7 — vol-pod mounts
check "vol-pod /etc/props has app.properties" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config exec vol-pod -- \
        cat /etc/props/app.properties | grep -q 'color=blue'"
check_eq "vol-pod can read the secret" \
    "$(k exec vol-pod -n config -- cat /etc/creds/password 2>/dev/null || true)" \
    'S3cr3t!'
check_jsonpath "creds mount is readOnly" \
    pod/vol-pod \
    '{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/creds")].readOnly}' \
    'true' -n config

# Task 8 — LOG_LEVEL updated + rolled out
check_jsonpath "app-config LOG_LEVEL is debug" \
    configmap/app-config '{.data.LOG_LEVEL}' 'debug' -n config
check "a reader pod sees LOG_LEVEL=debug" \
    bash -c "kubectl --context $KUBE_CONTEXT -n config exec \
        \$(kubectl --context $KUBE_CONTEXT -n config get pods -l app=reader \
            --field-selector=status.phase=Running --no-headers \
            | grep -v Terminating | awk '{print \$1}' | head -1) -- env \
        | grep -q '^LOG_LEVEL=debug$'"

# Task 9 — immutable ConfigMap
check_jsonpath "static-config is immutable" \
    configmap/static-config '{.immutable}' 'true' -n config

# Task 10 — password.txt decoded
check_eq "password.txt decoded" \
    "$(cat "$OUT_DIR/password.txt" 2>/dev/null | tr -d '[:space:]' || true)" \
    'S3cr3t!'

finish_checks
