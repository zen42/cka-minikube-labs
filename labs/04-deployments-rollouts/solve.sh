#!/usr/bin/env bash
# Lab 04 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — deployment web, 3 replicas, nginx:1.26
k create deployment web --image=nginx:1.26 --replicas=3 -n deploy \
    --dry-run=client -o yaml | k apply -f - >/dev/null
wait_rollout deploy web 180s

# Task 2 — scale to 5
k scale deployment web --replicas=5 -n deploy >/dev/null
wait_rollout deploy web 180s

# Task 3 — image 1.27 + change-cause
k set image deployment/web nginx=nginx:1.27 -n deploy >/dev/null
k annotate deployment web \
    kubernetes.io/change-cause="update to 1.27" -n deploy --overwrite >/dev/null
wait_rollout deploy web 180s

# Task 4 — save rollout history
k rollout history deployment/web -n deploy > "$OUT_DIR/history.txt"

# Task 5 — break api, observe, undo
k set image deployment/api nginx=nginx:1.99-doesnotexist -n deploy >/dev/null
wait_for "api pod in ImagePullBackOff" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n deploy get pods -l app=api \
        -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' \
        2>/dev/null | grep -q 'ImagePullBackOff\|ErrImagePull'"
k rollout undo deployment/api -n deploy >/dev/null
wait_rollout deploy api 180s

# Task 6 — RollingUpdate strategy maxSurge=1 maxUnavailable=0
k patch deployment web -n deploy --type=merge -p \
    '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}' \
    >/dev/null

# Task 7 — pause, batch image+resources, resume (single rollout)
k rollout pause deployment/web -n deploy >/dev/null
k set image deployment/web nginx=nginx:1.28 -n deploy >/dev/null
k set resources deployment web -n deploy \
    --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi >/dev/null
k rollout resume deployment/web -n deploy >/dev/null
wait_rollout deploy web 180s

# Task 8 — undo to revision 2
k rollout undo deployment/web --to-revision=2 -n deploy >/dev/null
wait_rollout deploy web 180s

# Task 9 — recreate.yaml manifest + apply
cat > "$OUT_DIR/recreate.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-app
  namespace: deploy
spec:
  replicas: 2
  strategy:
    type: Recreate
  selector:
    matchLabels: {app: recreate-app}
  template:
    metadata:
      labels: {app: recreate-app}
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
k apply -f "$OUT_DIR/recreate.yaml" >/dev/null
wait_rollout deploy recreate-app 120s

# Task 10 — minReadySeconds + progressDeadlineSeconds
k patch deployment web -n deploy --type=merge -p \
    '{"spec":{"minReadySeconds":5,"progressDeadlineSeconds":300}}' >/dev/null
wait_rollout deploy web 180s

# Task 11 — current ReplicaSet name to file
k get rs -n deploy -o json \
    | jq -r '.items[] | select(.spec.replicas>0
             and (.metadata.ownerReferences[0].name=="web")) | .metadata.name' \
    > "$OUT_DIR/current-rs.txt"

# Task 12 — scale api to 0
k scale deployment api --replicas=0 -n deploy >/dev/null

info "lab 04 solved"
