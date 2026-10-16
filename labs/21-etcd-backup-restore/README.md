# Lab 21 – etcd Backup & Restore

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 20

The CKA classic: take an `etcdctl` snapshot of the cluster's etcd and
restore it with `etcdutl`. You will *watch* the cluster state roll back —
a ConfigMap created after the snapshot disappears.

## Objectives

- `etcdctl endpoint health / member list / snapshot save` with TLS
- `etcdutl snapshot status / snapshot restore`
- Restoring a static-pod etcd: manifest out, data-dir swap, manifest in
- Proving the restore with pre/post marker objects

## Environment

- **Namespace:** `etcd-lab` (setup seeds ConfigMap `before-snapshot`).
- **Output dir:** `~/cka-labs-out/21/`
- **Start here:** `make lab-21`
- etcd is a static pod on the control-plane node. All etcd commands run
  inside the node — `minikube -p cka-labs ssh` then `sudo`. Setup copies
  `etcdctl`/`etcdutl` to `/usr/local/bin/` in the node.
- Node commands that save a file run from the host:
  `minikube -p cka-labs ssh -- <command> > ~/cka-labs-out/21/<file>`.
  Plain `minikube -p cka-labs ssh` is fine for interactive exploration —
  but the saved file must be produced from the host. (The etcd snapshot
  itself at `/var/lib/minikube/etcd-backup/snapshot.db` correctly lives
  ON the node.)
- Connection flags for this cluster:
  `--endpoints=https://127.0.0.1:2379`
  `--cacert=/var/lib/minikube/certs/etcd/ca.crt`
  `--cert=/var/lib/minikube/certs/etcd/server.crt`
  `--key=/var/lib/minikube/certs/etcd/server.key`
  etcd data dir: `/var/lib/minikube/etcd`; manifest:
  `/etc/kubernetes/manifests/etcd.yaml`.
- **Warning:** the restore rewinds *the whole cluster* to the snapshot.
  Any other lab's live state will be rolled back — finish and tear down
  other labs first.

## Tasks

1. Run on the node (via `minikube -p cka-labs ssh --`), saving from the
   host: `etcdctl ... endpoint health` and
   `etcdctl ... member list -w table` to
   `~/cka-labs-out/21/endpoint-health.txt` and `members.txt`.
2. `etcdctl ... snapshot save /var/lib/minikube/etcd-backup/snapshot.db`
   (the snapshot file stays on the node), then validate it:
   `etcdutl snapshot status ... -w table` →
   `~/cka-labs-out/21/snapshot-status.txt` (host file — redirect from
   the host).
3. Back on the host, create ConfigMap `after-snapshot` in `etcd-lab`
   (marker `after`) — it exists only because it is *after* the snapshot.
4. Restore:
   - `etcdutl snapshot restore /var/lib/minikube/etcd-backup/snapshot.db
     --data-dir /var/lib/minikube/etcd-restored` with `--name`,
     `--initial-cluster`, and `--initial-advertise-peer-urls` copied
     from the etcd flags in `/etc/kubernetes/manifests/etcd.yaml`.
   - Move the manifest aside (`mv .../etcd.yaml /tmp/`) and wait until
     `sudo crictl ps --name etcd` returns nothing.
   - `mv /var/lib/minikube/etcd /var/lib/minikube/etcd.pre-restore` and
     `mv /var/lib/minikube/etcd-restored /var/lib/minikube/etcd`.
   - Move the manifest back. (The exam's alternative is editing the
     manifest's `hostPath` to the restored dir; leaving it untouched
     keeps minikube's own bookkeeping happy.)
   - Wait for `kubectl get --raw /readyz` to return `ok` again, then
     **restart the control-plane components** (`sudo crictl stop
     $(sudo crictl ps --name kube-apiserver -q)`, same for
     `kube-controller-manager` and `kube-scheduler` — the kubelet
     brings them right back) and wait for `ok` once more.
5. Save `kubectl get cm -n etcd-lab` to
   `~/cka-labs-out/21/cm-after-restore.txt` — `before-snapshot` must be
   there and `after-snapshot` gone — and
   `etcdctl ... endpoint status -w table` to `endpoint-status.txt`.

## Verify

```bash
make verify-21     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-21   # from the repo root — or ./teardown.sh in this directory
```

Deletes the namespace, removes the backup/restored/pre-restore dirs on
the node, and the output dir. The restored etcd data *stays* — it is the
cluster now.

### If the API never comes back

```bash
minikube -p cka-labs ssh
# put the old data back and force etcd up again:
sudo mv /var/lib/minikube/etcd /var/lib/minikube/etcd.failed-restore
sudo mv /var/lib/minikube/etcd.pre-restore /var/lib/minikube/etcd
# if the manifest is still parked:
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
```

Last resort: `make reset-cluster` rebuilds the lab cluster (only the
`cka-labs` profile).

## Docs

- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
