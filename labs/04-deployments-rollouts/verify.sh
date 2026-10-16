#!/usr/bin/env bash
# Lab 04 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — deployment web exists
check_resource "deployment web exists" deployment web -n deploy

# Task 2 — scaled to 5
check_jsonpath "web spec.replicas is 5" \
    deployment/web '{.spec.replicas}' '5' -n deploy
check_jsonpath "web has 5 available replicas" \
    deployment/web '{.status.availableReplicas}' '5' -n deploy

# Task 3 — change-cause recorded (image lands at 1.27 again after task 8)
check_jsonpath "web annotated update to 1.27" \
    deployment/web '{.metadata.annotations.kubernetes\.io/change-cause}' \
    'update to 1.27' -n deploy

# Task 4 — history.txt saved
check_file_contains "history.txt has a REVISION column" \
    "$OUT_DIR/history.txt" 'REVISION'
check_file_contains "history.txt shows the change-cause" \
    "$OUT_DIR/history.txt" 'update to 1\.27'

# Task 5 — api recovered: image back to 1.26, undo minted a new revision
# (undo renumbers the revived RS to max+1, so history shows e.g. 2,3)
check_jsonpath "api image rolled back to nginx:1.26" \
    deployment/api '{.spec.template.spec.containers[0].image}' \
    'nginx:1.26' -n deploy
check "api rollout history shows revision 3 (undo)" \
    bash -c "kubectl --context $KUBE_CONTEXT rollout history \
        deployment/api -n deploy | grep -qE '^3\s'"
check_fails "no api pod stuck in ImagePullBackOff" \
    bash -c "kubectl --context $KUBE_CONTEXT -n deploy get pods -l app=api \
        -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' \
        | grep -q 'ImagePullBackOff\|ErrImagePull'"

# Task 6 — strategy set
check_jsonpath "web maxSurge is 1" \
    deployment/web '{.spec.strategy.rollingUpdate.maxSurge}' '1' -n deploy
check_jsonpath "web maxUnavailable is 0" \
    deployment/web '{.spec.strategy.rollingUpdate.maxUnavailable}' '0' -n deploy

# Task 7 — pause-batched rollout: image+resources landed in ONE rollout, so
# web has exactly 3 ReplicaSets (1.26, 1.27, 1.28+resources). A learner who
# didn't pause would have 4.
check "web has exactly 3 ReplicaSets (pause batched the changes)" \
    bash -c "test \$(kubectl --context $KUBE_CONTEXT -n deploy get rs \
        -l app=web --no-headers | wc -l) -eq 3"

# Task 8 — undo to revision 2: image 1.27, no resources
check_jsonpath "web image is nginx:1.27 after undo" \
    deployment/web '{.spec.template.spec.containers[0].image}' \
    'nginx:1.27' -n deploy
check "web pod template has no resource requests" \
    bash -c "test -z \"\$(kubectl --context $KUBE_CONTEXT -n deploy get deploy web \
        -o jsonpath='{.spec.template.spec.containers[0].resources.requests}')\""

# Task 9 — recreate-app via manifest
check_file_contains "recreate.yaml saved" \
    "$OUT_DIR/recreate.yaml" 'type: Recreate'
check_jsonpath "recreate-app strategy is Recreate" \
    deployment/recreate-app '{.spec.strategy.type}' 'Recreate' -n deploy
check_jsonpath "recreate-app has 2 available replicas" \
    deployment/recreate-app '{.status.availableReplicas}' '2' -n deploy

# Task 10 — readiness/progress settings
check_jsonpath "web minReadySeconds is 5" \
    deployment/web '{.spec.minReadySeconds}' '5' -n deploy
check_jsonpath "web progressDeadlineSeconds is 300" \
    deployment/web '{.spec.progressDeadlineSeconds}' '300' -n deploy

# Task 11 — current-rs.txt names the live ReplicaSet
_rs="$(cat "$OUT_DIR/current-rs.txt" 2>/dev/null | tr -d '[:space:]' || true)"
check "current-rs.txt names an existing RS" \
    bash -c "kubectl --context $KUBE_CONTEXT -n deploy get rs '$_rs' >/dev/null 2>&1"
if [[ -n "$_rs" ]]; then
    check_eq "named RS is owned by web" \
        "$(k -n deploy get rs "$_rs" \
            -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null || true)" \
        "web"
    check_eq "named RS replicas match web" \
        "$(k -n deploy get rs "$_rs" -o jsonpath='{.status.replicas}' \
            2>/dev/null || true)" \
        "$(k -n deploy get deploy web -o jsonpath='{.spec.replicas}' \
            2>/dev/null || echo -1)"
else
    fail "current-rs.txt names an existing RS (file empty or missing)"
    fail "named RS is owned by web (file empty or missing)"
    fail "named RS replicas match web (file empty or missing)"
fi

# Task 12 — api scaled to 0
check_jsonpath "api spec.replicas is 0" \
    deployment/api '{.spec.replicas}' '0' -n deploy

finish_checks
