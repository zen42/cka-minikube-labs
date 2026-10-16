#!/usr/bin/env bash
# Lab 14 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — label m02
k label node cka-labs-m02 disktype=ssd --overwrite >/dev/null

# Task 2 — ssd-pod via nodeSelector
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ssd-pod
  labels:
    app: ssd
spec:
  nodeSelector:
    disktype: ssd
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready sched ssd-pod 120s

# Task 3 — required + preferred node affinity
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: affinity-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - {key: disktype, operator: In, values: [ssd, nvme]}
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - {key: kubernetes.io/hostname, operator: In,
             values: [cka-labs-m03]}
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready sched affinity-pod 120s

# Task 4 — spread: 3 replicas, required pod anti-affinity
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread
spec:
  replicas: 3
  selector:
    matchLabels: {app: spread}
  template:
    metadata:
      labels: {app: spread}
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - topologyKey: kubernetes.io/hostname
            labelSelector:
              matchLabels: {app: spread}
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
wait_rollout sched spread 180s

# Task 5 — buddy: required pod affinity to app=ssd
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: buddy
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels: {app: ssd}
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready sched buddy 120s

# Task 6 — taint m03
k taint node cka-labs-m03 dedicated=gpu:NoSchedule --overwrite >/dev/null

# Task 7 — gpu-job tolerates the taint and pins to m03
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gpu-job
spec:
  nodeSelector:
    kubernetes.io/hostname: cka-labs-m03
  tolerations:
  - {key: dedicated, operator: Equal, value: gpu, effect: NoSchedule}
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready sched gpu-job 120s

# Task 8 — no-toleration: repelled by the taint
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-toleration
spec:
  nodeSelector:
    kubernetes.io/hostname: cka-labs-m03
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_for "no-toleration marked Unschedulable" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT -n sched get pod \
        no-toleration \
        -o jsonpath='{.status.conditions[?(@.type==\"PodScheduled\")].reason}' \
        2>/dev/null | grep -q Unschedulable"

# Task 9 — tier-spread: 6 replicas, skew 1, Honor node taints
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tier-spread
spec:
  replicas: 6
  selector:
    matchLabels: {app: tier-spread}
  template:
    metadata:
      labels: {app: tier-spread}
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        nodeTaintsPolicy: Honor
        labelSelector:
          matchLabels: {app: tier-spread}
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
wait_rollout sched tier-spread 240s

# Task 10 — pinned via nodeName (scheduler bypassed)
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pinned
spec:
  nodeName: cka-labs
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready sched pinned 120s

# Task 11 — PriorityClass + pod using it
k create priorityclass high-prio --value=100000 \
    --global-default=false 2>/dev/null \
    || k get priorityclass high-prio >/dev/null
k apply -n sched -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: important
spec:
  priorityClassName: high-prio
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready sched important 120s

# Task 12 — cordon m02 and record node state
k cordon cka-labs-m02 >/dev/null
k get nodes > "$OUT_DIR/nodes.txt"

# Task 13 — uncordon
k uncordon cka-labs-m02 >/dev/null

info "lab 14 solved"
