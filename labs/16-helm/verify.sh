#!/usr/bin/env bash
# Lab 16 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — repo added, versions listed
check_file_contains "search.txt lists podinfo/podinfo" \
    "$OUT_DIR/search.txt" 'podinfo/podinfo'
check_file_contains "search.txt lists the pinned chart version" \
    "$OUT_DIR/search.txt" "$PODINFO_CHART_VERSION"

# Task 2 — default values dumped
check_file_contains "values-default.yaml has replicaCount" \
    "$OUT_DIR/values-default.yaml" 'replicaCount:'

# Task 3+4+5 — release exists; after the rollback it is at revision 3
# with 2 replicas again (upgrade->rollback is proven by the revision).
check "release 'frontend' is deployed" \
    h status frontend -n helm
_rev="$(h list -n helm -o json 2>/dev/null \
    | jq -r '.[] | select(.name=="frontend") | .revision')"
check_eq "frontend is at revision 3 (upgrade + rollback)" "$_rev" "3"
check_jsonpath "frontend-podinfo back to 2 replicas" \
    deploy/frontend-podinfo '{.spec.replicas}' '2' -n helm
check "frontend-podinfo is available" \
    deploy_available helm frontend-podinfo

# Task 5 — history saved
check_file_contains "history.txt shows revisions" \
    "$OUT_DIR/history.txt" 'REVISION'

# Task 6 — current user-supplied values saved
check_file_contains "get-values.yaml shows replicaCount" \
    "$OUT_DIR/get-values.yaml" 'replicaCount'

# Task 7 — rendered chart + release was uninstalled in task 9
check_file_contains "webapp-rendered.yaml renders nginx" \
    "$OUT_DIR/webapp-rendered.yaml" 'nginx'
check_file_contains "webapp-rendered.yaml has 2 replicas" \
    "$OUT_DIR/webapp-rendered.yaml" 'replicas: 2'

# Task 8 — chart archive pulled
check "chart archive podinfo-$PODINFO_CHART_VERSION.tgz exists" \
    test -f "$OUT_DIR/podinfo-$PODINFO_CHART_VERSION.tgz"

# Task 9 — webapp gone, frontend stays
check_absent "deployment webapp uninstalled" \
    deployment webapp -n helm
check_fails "release 'webapp' is gone" \
    h status webapp -n helm
check "release 'frontend' still present" \
    h status frontend -n helm

# Task 10 — releases.json
check_file_contains "releases.json contains frontend" \
    "$OUT_DIR/releases.json" 'frontend'

finish_checks
