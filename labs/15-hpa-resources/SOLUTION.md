# Lab 15 – Solution

### Task 1

```bash
kubectl top nodes > ~/cka-labs-out/15/top-nodes.txt
```

### Task 2

```bash
kubectl create deployment php-apache -n autoscale \
    --image=registry.k8s.io/hpa-example --port=80
kubectl set resources deployment php-apache -n autoscale \
    --requests=cpu=200m --limits=cpu=500m
kubectl expose deployment php-apache -n autoscale --port=80
```

### Task 3

```bash
kubectl autoscale deployment php-apache -n autoscale \
    --cpu-percent=50 --min=1 --max=5
```

### Task 4

```bash
kubectl apply -n autoscale -f - <<'EOF'
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
kubectl get hpa -n autoscale -w   # desiredReplicas climbs to >= 2 in ~2-4 min
```

Why: metrics-server scrapes ~every 60s and the HPA averages utilization
against the `200m` request — sustained wget loops push it past 50%.

### Task 5

```bash
kubectl top pod -n autoscale --containers \
    > ~/cka-labs-out/15/top-pods.txt
```

### Task 6

```bash
kubectl apply -n autoscale -f - <<'EOF'
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
  echo "$p=$(kubectl get pod $p -n autoscale \
      -o jsonpath='{.status.qosClass}')"
done > ~/cka-labs-out/15/qos.txt
```

### Task 7

```bash
kubectl apply -n autoscale -f - <<'EOF'
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
kubectl apply -n autoscale -f - <<'EOF'
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
kubectl get pod no-resources -n autoscale -o yaml | grep -A3 requests
```

### Task 8

```bash
kubectl apply -n autoscale -f - <<'EOF'
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
kubectl describe resourcequota team-quota -n autoscale
```

### Task 9

```bash
kubectl apply -n autoscale -f - <<'EOF'
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
```

### Task 10

```bash
kubectl scale deployment load -n autoscale --replicas=0
kubectl get hpa -n autoscale > ~/cka-labs-out/15/hpa.txt
```
