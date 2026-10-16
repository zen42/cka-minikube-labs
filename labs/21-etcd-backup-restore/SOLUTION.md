# Lab 21 – Solution

All etcd commands run inside the control-plane node:

```bash
minikube -p cka-labs ssh
sudo -i    # everything below as root
ETCDCTL="etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/var/lib/minikube/certs/etcd/ca.crt \
    --cert=/var/lib/minikube/certs/etcd/server.crt \
    --key=/var/lib/minikube/certs/etcd/server.key"
```

`$OUT` is `~/cka-labs-out/21` (on the host — redirect there from the
host side, or write under `/tmp` inside the node and copy out).

### Task 1

```bash
$ETCDCTL endpoint health            # -> endpoint-health.txt
$ETCDCTL member list -w table       # -> members.txt
```

### Task 2

```bash
mkdir -p /var/lib/minikube/etcd-backup
$ETCDCTL snapshot save /var/lib/minikube/etcd-backup/snapshot.db
etcdutl snapshot status /var/lib/minikube/etcd-backup/snapshot.db \
    -w table                        # -> snapshot-status.txt
```

### Task 3

```bash
# on the host:
kubectl create configmap after-snapshot -n etcd-lab \
    --from-literal=marker=after
```

### Task 4

```bash
# inside the node, as root:
M=/etc/kubernetes/manifests/etcd.yaml
NAME=$(grep -o -- '--name=[^ ]*' $M | head -1 | cut -d= -f2-)
IC=$(grep -o -- '--initial-cluster=[^ ]*' $M | head -1 | cut -d= -f2-)
PEER=$(grep -o -- '--initial-advertise-peer-urls=[^ ]*' $M \
    | head -1 | cut -d= -f2-)

etcdutl snapshot restore /var/lib/minikube/etcd-backup/snapshot.db \
    --data-dir /var/lib/minikube/etcd-restored \
    --name "$NAME" --initial-cluster "$IC" \
    --initial-advertise-peer-urls "$PEER"

mv $M /tmp/etcd.yaml
# wait until: crictl ps --name etcd   # -> empty
mv /var/lib/minikube/etcd /var/lib/minikube/etcd.pre-restore
mv /var/lib/minikube/etcd-restored /var/lib/minikube/etcd
mv /tmp/etcd.yaml $M
```

Why: `--initial-cluster`/`--name`/`--initial-advertise-peer-urls` must
match the running member or the restored node forms a *new* cluster the
apiserver can't reach. The kubelet restarts the static pod seconds after
the manifest returns; `kubectl get --raw /readyz` flips to `ok` once
etcd serves again.

```bash
# then restart the control plane — without this their watch/informer
# caches keep serving post-snapshot objects forever (the rewound
# etcd's revision counter is lower than the caches', so they never
# relist):
for comp in kube-apiserver kube-controller-manager kube-scheduler; do
    crictl stop $(crictl ps --name $comp -q)
done
# wait for: kubectl get --raw /readyz   (on the host) -> ok
```

### Task 5

```bash
kubectl get cm -n etcd-lab          # -> cm-after-restore.txt
# before-snapshot present, after-snapshot absent  => restore worked
$ETCDCTL endpoint status -w table   # -> endpoint-status.txt
```
