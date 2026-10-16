# Lab 23 – Solution

`$OUT` is `~/cka-labs-out/23`. Node shell: `minikube -p cka-labs ssh -n
<node>` (sudo is passwordless inside).

### Task 1

```bash
kubectl get nodes -o wide > $OUT/nodes.txt      # m03 -> NotReady
kubectl describe node cka-labs-m03 > $OUT/describe-m03.txt
kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}' \
    > $OUT/notready-node.txt
```

Why: `describe`'s Conditions table shows `Ready Unknown` — the kubelet
stopped heart-beating (lastHeartbeatTime goes stale ~40s).

### Task 2

```bash
minikube -p cka-labs ssh -n cka-labs-m03
sudo systemctl status kubelet --no-pager      # inactive (dead)
sudo journalctl -u kubelet --no-pager -n 50
sudo systemctl start kubelet
sudo systemctl enable kubelet
# files land on the host: redirect the ssh output into $OUT/...
```

### Task 3

```bash
kubectl -n ts-nodes rollout status deploy/node-app --timeout=240s
```

Why: `node-app` could not schedule while m03 was NotReady *and* would
not tolerate the m02 taint — a stopped kubelet only shows as Pending
pods, never as a pod error.

### Task 4

```bash
kubectl uncordon cka-labs-m02
```

### Task 5

```bash
kubectl describe node cka-labs-m02 | grep -i taint
kubectl taint node cka-labs-m02 maintenance=true:NoSchedule-
```

### Task 6

```bash
kubectl get events --field-selector involvedObject.kind=Node -A \
    > $OUT/node-events.txt
```

### Task 7

```bash
kubectl top nodes > $OUT/top-nodes.txt
kubectl describe node cka-labs \
    | sed -n '/Allocated resources/,/Events/p' > $OUT/alloc.txt
```

### Task 8

```bash
kubectl drain cka-labs-m03 --ignore-daemonsets --delete-emptydir-data
kubectl get nodes > $OUT/drained.txt   # m03 -> Ready,SchedulingDisabled
kubectl uncordon cka-labs-m03
```

### Task 9

```bash
kubectl get node cka-labs-m03 \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")]}' \
    > $OUT/m03-ready.txt
```
