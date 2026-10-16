# Lab 04 – Solution

### Task 1

```bash
kubectl create deployment web --image=nginx:1.26 --replicas=3 -n deploy
```

### Task 2

```bash
kubectl scale deployment web --replicas=5 -n deploy
kubectl rollout status deployment web -n deploy
```

### Task 3

```bash
kubectl set image deployment/web nginx=nginx:1.27 -n deploy
kubectl annotate deployment web \
    kubernetes.io/change-cause="update to 1.27" -n deploy
```

### Task 4

```bash
kubectl rollout history deployment/web -n deploy \
    > ~/cka-labs-out/04/history.txt
```

### Task 5

```bash
kubectl set image deployment/api nginx=nginx:1.99-doesnotexist -n deploy
kubectl rollout status deployment/api -n deploy     # stalls; watch pods
kubectl get pods -n deploy                          # ImagePullBackOff
kubectl rollout undo deployment/api -n deploy
kubectl rollout status deployment/api -n deploy
```

Why: `rollout undo` rolls back to the previous ReplicaSet — the fastest way
to recover from a bad image. The bad rollout still counts in the history.

### Task 6

```bash
kubectl patch deployment web -n deploy --type=merge -p \
    '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
```

### Task 7

```bash
kubectl rollout pause deployment/web -n deploy
kubectl set image deployment/web nginx=nginx:1.28 -n deploy
kubectl set resources deployment web -n deploy \
    --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
kubectl rollout resume deployment/web -n deploy
kubectl rollout status deployment/web -n deploy
```

Why: a paused deployment records spec changes without starting a rollout —
both changes merge into a single new ReplicaSet when resumed (3 revisions
total: create, 1.27, 1.28+resources).

### Task 8

```bash
kubectl rollout undo deployment/web --to-revision=2 -n deploy
```

Why: revision 2 is the `nginx:1.27` template — without the resources stanza
added in revision 3. Undo proves the template is versioned, not just the
image.

### Task 9

```bash
cat > ~/cka-labs-out/04/recreate.yaml <<'EOF'
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
kubectl apply -f ~/cka-labs-out/04/recreate.yaml
```

### Task 10

```bash
kubectl patch deployment web -n deploy --type=merge -p \
    '{"spec":{"minReadySeconds":5,"progressDeadlineSeconds":300}}'
```

### Task 11

```bash
kubectl get rs -n deploy -o json \
  | jq -r '.items[] | select(.spec.replicas>0
           and (.metadata.ownerReferences[0].name=="web")) | .metadata.name' \
  > ~/cka-labs-out/04/current-rs.txt
```

(Or eyeball `kubectl get rs -n deploy` — the RS with READY > 0.)

### Task 12

```bash
kubectl scale deployment api --replicas=0 -n deploy
```
