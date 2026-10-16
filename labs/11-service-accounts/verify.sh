#!/usr/bin/env bash
# Lab 11 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

SA="system:serviceaccount:sa:app-sa"

# Task 1 — serviceaccount exists
check_resource "serviceaccount app-sa exists" serviceaccount app-sa -n sa

# Task 2 — app-sa-lister binding + effective perms
check_jsonpath "app-sa-lister binds role pod-lister" \
    rolebinding/app-sa-lister '{.roleRef.name}' 'pod-lister' -n sa
check_eq "app-sa can list pods" \
    "$(k auth can-i list pods -n sa --as="$SA" 2>/dev/null)" "yes"
check_eq "app-sa cannot delete pods" \
    "$(k auth can-i delete pods -n sa --as="$SA" 2>/dev/null)" "no"

# Task 3 — api-client runs as app-sa
check_jsonpath "api-client uses app-sa" \
    pod/api-client '{.spec.serviceAccountName}' 'app-sa' -n sa
check_jsonpath "api-client is Running" \
    pod/api-client '{.status.phase}' 'Running' -n sa

# Task 4 — pods-via-api.txt is a PodList containing api-client
check_file_contains "pods-via-api.txt is a PodList" \
    "$OUT_DIR/pods-via-api.txt" '"kind"[: ]+"PodList"'
check_file_contains "pods-via-api.txt lists api-client" \
    "$OUT_DIR/pods-via-api.txt" 'api-client'

# Task 5 — no-token pod has automount off and no token dir
check_jsonpath "no-token automountServiceAccountToken is false" \
    pod/no-token '{.spec.automountServiceAccountToken}' 'false' -n sa
check_fails "no-token has no serviceaccount mount" \
    k exec no-token -n sa -- ls /var/run/secrets/kubernetes.io/serviceaccount

# Task 6 — token.txt is a JWT; whoami resolves to the SA
check "token.txt is a 3-part JWT" \
    grep -Eq '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' \
    "$OUT_DIR/token.txt"
check_file_contains "whoami.txt shows the service account" \
    "$OUT_DIR/whoami.txt" 'system:serviceaccount:sa:app-sa'

# Task 7 — projected token volume + a real JWT inside
check_jsonpath "projected-token audience is vault" \
    pod/projected-token \
    '{.spec.volumes[0].projected.sources[0].serviceAccountToken.audience}' \
    'vault' -n sa
_tok="$(k exec projected-token -n sa -- \
    cat /var/run/secrets/tokens/token 2>/dev/null || true)"
check_match "projected token file holds a JWT" "$_tok" \
    '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'

# Task 8 — imagePullSecrets on app-sa
check_jsonpath "app-sa imagePullSecrets has regcred" \
    serviceaccount/app-sa '{.imagePullSecrets[0].name}' 'regcred' -n sa

# Task 9 — app-sa-view ClusterRoleBinding
check_jsonpath "app-sa-view binds ClusterRole view" \
    clusterrolebinding/app-sa-view '{.roleRef.name}' 'view'
check_eq "app-sa can list deployments cluster-wide" \
    "$(k auth can-i list deployments -n kube-system --as="$SA" 2>/dev/null)" \
    "yes"
check_eq "app-sa cannot create deployments" \
    "$(k auth can-i create deployments -n kube-system --as="$SA" \
        2>/dev/null)" "no"

# Task 10 — report file
check_file_contains "sa-report.txt lists app-sa" \
    "$OUT_DIR/sa-report.txt" 'app-sa'
check_file_contains "sa-report.txt lists app-sa-lister" \
    "$OUT_DIR/sa-report.txt" 'app-sa-lister'

finish_checks
