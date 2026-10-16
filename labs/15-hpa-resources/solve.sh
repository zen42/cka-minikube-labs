#!/usr/bin/env bash
# Lab 15 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — top nodes
k top nodes > "$OUT_DIR/top-nodes.txt"

# Task 2 — php-apache deployment + resources + service
k create deployment php-apache -n autoscale \
    --image=registry.k8s.io/hpa-example --port=80 2>/dev/null \
    || k get deployment php-apache -n autoscale >/dev/null
k set resources deployment php-apache -n autoscale \
    --requests=cpu=200m --limits=cpu=500m >/dev/null
k expose deployment php-apache -n autoscale --port=80 2>/dev/null \
    || k get service php-apache -n autoscale >/dev/null
wait_rollout autoscale php-apache 300s

# Task 3 — autoscale (v1-style CLI)
k autoscale deployment php-apache -n autoscale \
    --cpu-percent=50 --min=1 --max=5 2>/dev/null \
    || k get hpa php-apache -n autoscale >/dev/null

# Task 4 — load generator, then wait for scale-out
k apply -n autoscale -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load
spec:
  replicas: 2
  selector:
    matchLabels: {app: load}
  template:
    metadata:
      labels: {app: load}
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c",
                  "while true; do wget -q -O- -T 2 http://php-apache; done"]
EOF
wait_rollout autoscale load 120s
info "waiting for HPA to scale out (metrics-server needs ~2-4 min)..."
wait_for "hpa desiredReplicas >= 2" 360 \
    bash -c "kubectl --context $KUBE_CONTEXT -n autoscale get hpa \
        php-apache -o jsonpath='{.status.desiredReplicas}' 2>/dev/null \
        | grep -qE '^[2-9]'"

# Task 5 — top pods
k top pod -n autoscale --containers > "$OUT_DIR/top-pods.txt"

# Task 6 — QoS pods + classes to file
k apply -n autoscale -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: qos-guaranteed
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    resources:
      requests: {cpu: 100m, memory: 64Mi}
      limits:   {cpu: 100m, memory: 64Mi}
---
apiVersion: v1
kind: Pod
metadata:
  name: qos-burstable
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    resources:
      requests: {cpu: 50m, memory: 32Mi}
---
apiVersion: v1
kind: Pod
metadata:
  name: qos-besteffort
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
for p in qos-guaranteed qos-burstable qos-besteffort; do
    wait_pod_ready autoscale "$p" 120s
done
for p in qos-guaranteed qos-burstable qos-besteffort; do
    echo "$p=$(k get pod "$p" -n autoscale \
        -o jsonpath='{.status.qosClass}')"
done > "$OUT_DIR/qos.txt"

# Task 7 — LimitRange defaults + a pod that gets them injected
k apply -n autoscale -f - >/dev/null <<'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
spec:
  limits:
  - type: Container
    default:         {cpu: 200m, memory: 128Mi}
    defaultRequest:  {cpu: 100m, memory: 64Mi}
    max:             {cpu: "1"}
EOF
k apply -n autoscale -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-resources
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready autoscale no-resources 120s

# Task 8 — ResourceQuota (after LimitRange so later pods still schedule)
k apply -n autoscale -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
spec:
  hard:
    pods: "15"
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
EOF

# Task 9 — cache deployment + v2 memory HPA
k apply -n autoscale -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
spec:
  replicas: 1
  selector:
    matchLabels: {app: cache}
  template:
    metadata:
      labels: {app: cache}
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "3600"]
        resources:
          requests: {cpu: 50m, memory: 32Mi}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cache-hpa
  namespace: autoscale
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cache
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
EOF
wait_rollout autoscale cache 120s

# Task 10 — stop the load; record HPA state
k scale deployment load -n autoscale --replicas=0 >/dev/null
k get hpa -n autoscale > "$OUT_DIR/hpa.txt"

info "lab 15 solved"
