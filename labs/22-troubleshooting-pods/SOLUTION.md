# Lab 22 – Solution

`$OUT` is `~/cka-labs-out/22`; everything is in `-n ts-pods`.

### Task 1

```bash
kubectl describe pod -l app=img-typo -n ts-pods   # ImagePullBackOff
kubectl set image deployment/img-typo app=nginx:1.27 -n ts-pods
```

### Task 2

```bash
kubectl describe pod crash-app -n ts-pods          # Last State: exit 3
kubectl get pod crash-app -n ts-pods \
    -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' \
    > $OUT/crash-exit-code.txt
cat > $OUT/crash-app.yaml <<'EOF'   # write the fix to a file
apiVersion: v1
kind: Pod
metadata: {name: crash-app, namespace: ts-pods}
spec:
  containers:
  - name: app
    image: busybox:1.36
    env: [{name: FOO, value: bar}]
    command: ["sh", "-c",
      '[ -n "$FOO" ] || { echo "fatal: FOO is not set"; exit 3; }; sleep 3600']
EOF
kubectl replace --force -f $OUT/crash-app.yaml
# pod spec is immutable — replace --force deletes and recreates
```

### Task 3

```bash
kubectl describe pod -l app=probe-fail -n ts-pods  # probe on :8080
kubectl patch deployment probe-fail -n ts-pods --type=strategic -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"app","readinessProbe":{"httpGet":{"port":80}}}]}}}}'
kubectl rollout status deploy/probe-fail -n ts-pods
```

### Task 4

```bash
kubectl get pod oom-app -n ts-pods \
    -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason} {.status.containerStatuses[0].lastState.terminated.exitCode}' \
    > $OUT/oom-reason.txt        # "OOMKilled 137"
cat > $OUT/oom-app.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: oom-app, namespace: ts-pods}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - 'head -c 8M /dev/zero | tail -c 1 >/dev/null; sleep 3600'
    resources: {limits: {memory: 64Mi}}
EOF
kubectl replace --force -f $OUT/oom-app.yaml
```

Why: `tail /dev/zero` buffers an ever-growing partial line — unbounded
growth against a 32 MiB limit, so the cgroup OOM-killer SIGKILLs it:
`reason: OOMKilled`, **exit code 137** (128+9). Note that some runtimes
only surface the exit code (`reason: Error`, `exitCode: 137`) — 137 is
the tell there too. The fix needs *both* changes: the limit alone
doesn't shrink the workload.

### Task 5

```bash
kubectl describe pod pending-app -n ts-pods        # 0/1 nodes available: Insufficient cpu
kubectl describe pod pending-app -n ts-pods | grep -m1 Insufficient \
    > $OUT/pending-reason.txt
cat > $OUT/pending-app.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: pending-app, namespace: ts-pods}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    resources: {requests: {cpu: 100m}}
EOF
kubectl replace --force -f $OUT/pending-app.yaml
```

Why: `cpu: "100"` asks for 100 *cores* — a typo for `100m`.

### Task 6

```bash
kubectl describe pod cm-missing -n ts-pods         # configMap "app-settings" not found
kubectl create configmap app-settings -n ts-pods --from-literal=MODE=prod
# the kubelet retries env resolution; the pod starts on its own
```

### Task 7

```bash
kubectl debug quiet -n ts-pods --image=busybox:1.36 --target=quiet \
    -- sleep 3600
```

Why: the pause image has no shell — an ephemeral container gives you
one inside the pod's namespaces.

### Task 8

```bash
kubectl debug node/cka-labs -n default --image=busybox:1.36 \
    -- chroot /host cat /etc/hostname
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded \
    pod -l app=debug-pod -n default --timeout=120s 2>/dev/null || true
dbg=$(kubectl get pods -n default -o name | grep node-debugger)
kubectl logs "$dbg" -n default > $OUT/node-hostname.txt
kubectl delete "$dbg" -n default
```

### Task 9

```bash
kubectl logs sidecar-app -n ts-pods -c sidecar --tail=5 \
    > $OUT/sidecar.log
```

### Task 10

```bash
kubectl get events -n ts-pods --sort-by=.lastTimestamp > $OUT/events.txt
kubectl wait --for=condition=Ready pod -l app=probe-fail -n ts-pods \
    --timeout=60s
```
