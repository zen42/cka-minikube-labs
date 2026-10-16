# Lab 20 – Solution

kubeadm runs inside the control-plane node (it needs
`/etc/kubernetes/admin.conf`, which is root-only — hence `sudo`):

```bash
minikube -p cka-labs ssh
KUBEADM="sudo /var/lib/minikube/binaries/v1.34.11/kubeadm"
```

`$OUT` is `~/cka-labs-out/20`.

### Task 1

```bash
# inside the node (docker user needs sudo for these):
sudo swapon --show
sudo lsmod | grep br_netfilter
sudo sysctl net.ipv4.ip_forward
# all three -> $OUT/infra-prep.txt
```

### Task 2

```bash
$KUBEADM version -o yaml > $OUT/kubeadm-version.txt
kubectl version > $OUT/kubectl-version.txt
```

### Task 2

```bash
$KUBEADM token create --ttl 2h --print-join-command \
    --description cka-lab-20 > $OUT/join.txt
$KUBEADM token list > $OUT/tokens.txt
tok=$(awk '{for(i=1;i<NF;i++) if($i=="--token") print $(i+1)}' \
    $OUT/join.txt)
$KUBEADM token delete $tok
$KUBEADM token list > $OUT/tokens-after-delete.txt
```

Why: `--print-join-command` emits the worker-join line a real cluster
would paste on a new node; deleting the token afterwards keeps the
cluster clean.

### Task 3

```bash
# minikube's PKI lives under /var/lib/minikube/certs, not /etc/kubernetes/pki
$KUBEADM certs check-expiration --cert-dir /var/lib/minikube/certs \
    > $OUT/certs-expiration.txt
```

### Task 4

```bash
$KUBEADM upgrade plan > $OUT/upgrade-plan.txt 2>&1   # may fail offline
kubectl get cm kubeadm-config -n kube-system -o yaml \
    > $OUT/kubeadm-config.yaml
```

### Task 5

```bash
kubectl apply -n lifecycle -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  replicas: 6
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
      - {name: app, image: nginx:1.27}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: web-pdb, namespace: lifecycle}
spec:
  minAvailable: 4
  selector: {matchLabels: {app: web}}
EOF
kubectl -n lifecycle rollout status deploy/web --timeout=240s
```

### Task 6

```bash
kubectl cordon cka-labs-m02
```

### Task 7

```bash
kubectl drain cka-labs-m02 --ignore-daemonsets --delete-emptydir-data
```

Why: drain refuses by default when DaemonSet-managed or emptyDir-using
pods are present — these flags acknowledge both (calico-node is the
DaemonSet here). The evicted `web` pods reschedule onto the other
nodes; the PDB keeps at least 4 running during the move.

### Task 8

```bash
kubectl get node cka-labs-m02 \
    -o jsonpath='{.status.nodeInfo.kubeletVersion}' \
    > $OUT/kubelet-version.txt
```

### Task 9

```bash
kubectl uncordon cka-labs-m02
```

### Task 10

```bash
kubectl get nodes -o wide > $OUT/nodes-final.txt
```
