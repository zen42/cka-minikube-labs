#!/usr/bin/env bash
# Lab 18 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — the CRD itself
check_jsonpath "crd group is stable.example.com" \
    crd/crontabs.stable.example.com '{.spec.group}' 'stable.example.com'
check_jsonpath "crd is Namespaced" \
    crd/crontabs.stable.example.com '{.spec.scope}' 'Namespaced'
check_jsonpath "crd shortName ct" \
    crd/crontabs.stable.example.com '{.spec.names.shortNames[0]}' 'ct'
check_jsonpath "crd replicas schema is integer" \
    crd/crontabs.stable.example.com \
    '{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.replicas.type}' \
    'integer'
check_jsonpath "crd replicas max is 10" \
    crd/crontabs.stable.example.com \
    '{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.replicas.maximum}' \
    '10'

# Task 2 — explain output saved
check_file_contains "explain.txt documents cronSpec" \
    "$OUT_DIR/explain.txt" 'cronSpec'

# Task 3 — the two valid CRs
check_resource "crontab my-new-cron-object exists" \
    crontab my-new-cron-object -n crd-demo
check_resource "crontab my-other-cron exists" \
    crontab my-other-cron -n crd-demo
check_jsonpath "my-other-cron has 3 replicas" \
    crontab/my-other-cron '{.spec.replicas}' '3' -n crd-demo

# Task 4 — invalid CR was written down and is still rejected
check_file_contains "invalid.yaml asks for replicas 20" \
    "$OUT_DIR/invalid.yaml" 'replicas: 20'
check "invalid-error.txt recorded the rejection" \
    test -s "$OUT_DIR/invalid-error.txt"
check_fails "apiserver still rejects the invalid CR" \
    k apply -f "$OUT_DIR/invalid.yaml"

# Task 5 — shortName listing saved
check_file_contains "ct.txt lists my-new-cron-object" \
    "$OUT_DIR/ct.txt" 'my-new-cron-object'

# Task 6 — api-resources saved
check_file_contains "api-resources.txt lists crontabs" \
    "$OUT_DIR/api-resources.txt" 'crontabs'

# Task 7 — cert-manager operator installed and healthy
for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
    check "deploy/$d available" deploy_available cert-manager "$d"
done
check "release cert-manager is deployed" \
    h status cert-manager -n cert-manager

# Task 8 — ClusterIssuer + Certificate + generated Secret
check_resource "clusterissuer selfsigned exists" \
    clusterissuer selfsigned
check_jsonpath "clusterissuer is ready" \
    clusterissuer/selfsigned '{.status.conditions[0].status}' 'True'
check_jsonpath "certificate demo-cert is Ready" \
    certificate/demo-cert '{.status.conditions[0].status}' 'True' \
    -n crd-demo
check "secret demo-cert-tls holds tls.crt" \
    bash -c "kubectl --context $KUBE_CONTEXT -n crd-demo get secret \
        demo-cert-tls -o jsonpath='{.data.tls\.crt}' | grep -q ."

# Task 9 — CRD listing saved (>= 6 cert-manager CRDs)
_n="$(grep -c 'cert-manager' "$OUT_DIR/cert-manager-crds.txt" 2>/dev/null \
    || echo 0)"
check "cert-manager installed >= 6 CRDs" test "$_n" -ge 6

# Task 10 — describe output saved
check_file_contains "describe-crd.txt describes certificates" \
    "$OUT_DIR/describe-crd.txt" 'certificates.cert-manager.io'

finish_checks
