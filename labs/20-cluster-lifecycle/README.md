# Lab 20 – Cluster Lifecycle with kubeadm

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 19

The kubeadm side of cluster admin: versions, bootstrap tokens, certificate
expiry, upgrade planning, and the cordon/drain/uncordon dance a real
node upgrade needs.

## Objectives

- kubeadm-init prerequisites on a node (swap, `br_netfilter`,
  `ip_forward`, runtime, ports)
- `kubeadm version`, `token create/list/delete`, `certs check-expiration`
- `kubeadm upgrade plan` + the `kubeadm-config` ConfigMap
- `kubectl cordon` / `drain` / `uncordon` on a multi-node cluster
- PodDisruptionBudgets during voluntary disruption

## Concepts

**kubeadm-init prerequisites.** A kubeadm node needs: swap **off**
(`swapoff -a` + remove it from `/etc/fstab` — kubelet refuses to start
with swap on), the `br_netfilter` kernel module loaded so bridged pod
traffic crosses iptables (`lsmod | grep br_netfilter`), IPv4 forwarding
on (`sysctl net.ipv4.ip_forward` = 1), a CRI runtime listening
(containerd here), and open ports — 6443 (apiserver), 2379–2380 (etcd
client/peer), 10250 (kubelet). Task 1 inspects all of that. Fun fact:
minikube ships a 5 GiB swapfile *and* configures its kubelet to
tolerate it — a real `kubeadm init` host must not have one.

**Highly-available control planes.** kubeadm supports two topologies:
*stacked etcd* — etcd runs on each control-plane node (simplest, ≥3
nodes, losing 2 breaks quorum) — and *external etcd* — a separate etcd
cluster the apiservers share (more machines, easier to back up/scale
independently). Both put a **load balancer** (haproxy/nginx/keepalived)
in front of the apiservers; every node's kubelet, plus `kubeadm join`
and `init`, points at `controlPlaneEndpoint` (the LB address) instead
of one apiserver. On minikube there is a single control-plane node and
no LB, so HA can't be exercised for real — know the topology and the
flags (`--control-plane-endpoint`, `--upload-certs`, `kubeadm join
--control-plane`).

## Environment

- **Namespace:** `lifecycle`. **Nodes:** setup grows the cluster to
  3 (`cka-labs`, `cka-labs-m02`, `cka-labs-m03`).
- **Output dir:** `~/cka-labs-out/20/`
- **Start here:** `make lab-20`
- In this lab `kubeadm` lives inside the control-plane node —
  `minikube -p cka-labs ssh`, then
  `sudo /var/lib/minikube/binaries/v1.34.11/kubeadm ...`. In the real
  exam `kubeadm` is on `PATH` and the flow is identical.
- Multi-node needs `fs.inotify.max_user_instances >= 1024` on the
  host; `check-env.sh` tells you if yours is too low.

## Tasks

1. Kubeadm-init prerequisites: inside the control-plane node, save the
   output of `swapon --show`, `lsmod | grep br_netfilter`, and
   `sysctl net.ipv4.ip_forward` to `~/cka-labs-out/20/infra-prep.txt`.
2. Save `kubeadm version -o yaml` (inside the node) and
   `kubectl version` to `~/cka-labs-out/20/kubeadm-version.txt` and
   `kubectl-version.txt`.
3. `kubeadm token create --ttl 2h --print-join-command
   --description cka-lab-20` → save the join command to
   `~/cka-labs-out/20/join.txt`; save `kubeadm token list` to
   `tokens.txt`; then `kubeadm token delete` the token you made and
   save the list again to `tokens-after-delete.txt`.
4. Save `kubeadm certs check-expiration
   --cert-dir /var/lib/minikube/certs` to
   `~/cka-labs-out/20/certs-expiration.txt` (minikube keeps its PKI
   under `/var/lib/minikube/certs`, not the kubeadm default
   `/etc/kubernetes/pki`).
5. Save `kubeadm upgrade plan` output to
   `~/cka-labs-out/20/upgrade-plan.txt` (it may fail without internet —
   the file just needs the attempt's output), and
   `kubectl get cm kubeadm-config -n kube-system -o yaml` to
   `kubeadm-config.yaml`.
6. In namespace `lifecycle`, create deployment `web` (nginx:1.27,
   6 replicas) and PDB `web-pdb` with `minAvailable: 4`.
7. `kubectl cordon cka-labs-m02`.
8. `kubectl drain cka-labs-m02 --ignore-daemonsets
   --delete-emptydir-data`.
9. Record the drained node's kubelet version
   (`kubectl get node cka-labs-m02 -o
   jsonpath='{.status.nodeInfo.kubeletVersion}'`) to
   `~/cka-labs-out/20/kubelet-version.txt` — this is what
   `kubeadm upgrade node` would change.
10. `kubectl uncordon cka-labs-m02`.
11. Save `kubectl get nodes -o wide` to
    `~/cka-labs-out/20/nodes-final.txt`.

## Verify

```bash
make verify-20
```

## Clean up

```bash
make teardown-20
```

Uncordons all nodes, deletes leftover lab tokens, the namespace, and
the output dir. The worker nodes stay (see lab 14).

## Docs

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/
