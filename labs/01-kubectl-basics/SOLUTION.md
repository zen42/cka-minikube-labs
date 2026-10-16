# Lab 01 – Solution

### Task 1

```bash
kubectl create namespace basics
```

### Task 2

```bash
kubectl explain pod.spec.restartPolicy
echo "pod.spec.restartPolicy" > ~/cka-labs-out/01/restart-policy.txt
```

### Task 3

```bash
kubectl run nginx-pod --image=nginx:1.27 -n basics \
    --dry-run=client -o yaml > ~/cka-labs-out/01/pod.yaml
kubectl label -f ~/cka-labs-out/01/pod.yaml tier=web --local -o yaml \
    > /tmp/pod-labeled.yaml && mv /tmp/pod-labeled.yaml ~/cka-labs-out/01/pod.yaml
kubectl apply -f ~/cka-labs-out/01/pod.yaml
```

Why: `kubectl label --local` edits the manifest file without contacting the
API server — a fast way to add labels to a generated YAML.

### Task 4

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=2 -n basics
```

### Task 5

```bash
kubectl label deployment web app.kubernetes.io/part-of=shop -n basics
kubectl annotate deployment web owner=platform-team -n basics
```

### Task 6

```bash
kubectl patch deployment web -n basics -p '{"spec":{"replicas":3}}'
```

### Task 7

```bash
kubectl patch deployment web -n basics \
    --type=merge -p '{"spec":{"revisionHistoryLimit":5}}'
```

### Task 8

```bash
kubectl -n default get svc kubernetes \
    -o jsonpath='{.spec.clusterIP}' > ~/cka-labs-out/01/kubernetes-svc-ip.txt
```

### Task 9

```bash
kubectl -n kube-system get pods \
    -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName \
    --sort-by=.metadata.name > ~/cka-labs-out/01/kube-system-pods.txt
```

### Task 10

```bash
kubectl api-resources --namespaced=true --api-group=apps -o name \
    > ~/cka-labs-out/01/apps-resources.txt
```

### Task 11

```bash
kubectl delete deployment old-app -n cleanup-me
kubectl delete namespace cleanup-me
```

Why: deleting a namespace cascades to everything inside; the deployment
delete first is belt-and-braces to show both verbs.

### Task 12

```bash
kubectl get all -n basics -o wide > ~/cka-labs-out/01/basics-all.txt
```
