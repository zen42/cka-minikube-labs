# Lab 02 – Solution

### Task 1

```bash
kubectl run web --image=nginx:1.27 --port=80 --labels=app=web -n pods
```

### Task 2

```bash
kubectl run busy --image=busybox:1.36 --restart=Never \
    --env=GREETING=hello -n pods --command -- sleep 3600
```

Why: `--command --` makes the following args the container command instead
of an image name; `--restart=Never` keeps the pod bare (no Deployment).

### Task 3

```bash
kubectl logs crasher -n pods --previous | grep FATAL \
    > ~/cka-labs-out/02/crash-reason.txt
```

Why: `--previous` reads the log of the last terminated container — essential
for CrashLoopBackOff pods whose current container has just restarted.

### Task 4

```bash
kubectl logs multi -n pods -c sidecar --tail=20 > ~/cka-labs-out/02/sidecar.log
```

### Task 5

```bash
kubectl exec multi -n pods -c app -- cat /shared/status.txt \
    > ~/cka-labs-out/02/status.txt
```

Why: the emptyDir volume is shared between `app` and `sidecar`, so the file
written by the sidecar is visible to app.

### Task 6

```bash
kubectl exec busy -n pods -- sh -c 'echo world > /tmp/hello.txt'
```

### Task 7

```bash
kubectl cp pods/web:/etc/nginx/nginx.conf ~/cka-labs-out/02/nginx.conf
```

### Task 8

```bash
kubectl port-forward pod/web 8080:80 -n pods &
PF_PID=$!
sleep 3
curl -s localhost:8080 > ~/cka-labs-out/02/index.html
kill $PF_PID
```

Why: port-forward binds a local port to the pod without a Service — the
fastest way to sanity-check an app.

### Task 9

```bash
kubectl wait --for=condition=Ready pod/web -n pods --timeout=60s
kubectl get pod web -n pods -o jsonpath='{.spec.nodeName}' \
    > ~/cka-labs-out/02/web-node.txt
```

### Task 10

```bash
kubectl describe pod crasher -n pods > ~/cka-labs-out/02/crasher-describe.txt
```

### Task 11

```bash
kubectl delete pod crasher -n pods
```
