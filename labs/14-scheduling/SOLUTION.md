# Lab 14 – Solution

### Task 1

```bash
kubectl label node cka-labs-m02 disktype=ssd
```

### Task 2

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

### Task 3

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

Why: only `cka-labs-m02` satisfies the required term, so the preferred
term (m03) is ignored — preference ≠ requirement.

### Task 4

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

### Task 5

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

### Task 6

```bash
kubectl taint node cka-labs-m03 dedicated=gpu:NoSchedule
```

### Task 7

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

### Task 8

```bash
kubectl apply -n sched -f - <<'EOF'
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
kubectl get pod no-toleration -n sched   # Pending — taint repels it
```

### Task 9

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

Why `nodeTaintsPolicy: Honor`: without it the tainted m03 still counts as
a domain, and `DoNotSchedule` would leave pods Pending trying to balance
onto it. With Honor, only the two untainted nodes are domains → 3+3.

### Task 10

```bash
kubectl apply -n sched -f - <<'EOF'
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
```

Why: `nodeName` binds the pod directly — the scheduler is skipped, so
taints are irrelevant (kubelet admits it).

### Task 11

```bash
kubectl create priorityclass high-prio --value=100000 \
    --global-default=false
kubectl apply -n sched -f - <<'EOF'
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
```

### Task 12

```bash
kubectl cordon cka-labs-m02
kubectl get nodes > ~/cka-labs-out/14/nodes.txt
```

### Task 13

```bash
kubectl uncordon cka-labs-m02
```
