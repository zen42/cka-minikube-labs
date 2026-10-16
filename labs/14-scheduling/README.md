# Lab 14 – Scheduling: Selectors, Affinity & Taints

**Domain:** Workloads & Scheduling (15%) · **Builds on:** Lab 04

Placement control: `nodeSelector`, node/pod affinity & anti-affinity,
taints & tolerations, `topologySpreadConstraints`, `nodeName`, priorities,
cordon/uncordon.

## Objectives

- `nodeSelector` + node labels
- `nodeAffinity` required vs preferred; `podAffinity`/`podAntiAffinity`
- Taints (`NoSchedule`), tolerations, `nodeTaintsPolicy`
- `topologySpreadConstraints`, `nodeName`, `PriorityClass`, cordon

## Environment

- **Namespace:** `sched`.
- **Cluster:** setup adds two workers — `cka-labs-m02`, `cka-labs-m03`
  (control plane is `cka-labs`). They stay after teardown;
  `make reset-cluster` returns to one node.
- **Output dir:** `~/cka-labs-out/14/`
- **Start here:** `make lab-14`
- Adding nodes takes a couple of minutes and uses ~2× the minikube memory
  allocation.

## Tasks

1. Label node `cka-labs-m02` `disktype=ssd`.
2. Create pod `ssd-pod` (busybox:1.36 `sleep 3600`, label `app=ssd`) with
   `nodeSelector: disktype: ssd`.
3. Create pod `affinity-pod` (busybox sleep) with node affinity:
   *required* `disktype In [ssd, nvme]` AND *preferred* (weight 1)
   `kubernetes.io/hostname In [cka-labs-m03]`.
4. Create deployment `spread` (busybox sleep, 3 replicas, label
   `app=spread`) with *required* pod anti-affinity on
   `kubernetes.io/hostname` against `app=spread` — one pod per node.
5. Create pod `buddy` (busybox sleep) with *required* pod affinity to
   `app=ssd` pods on `kubernetes.io/hostname` — it must land next to
   `ssd-pod`.
6. Taint `cka-labs-m03` `dedicated=gpu:NoSchedule`.
7. Create pod `gpu-job` (busybox sleep) with a toleration for
   `dedicated=gpu:NoSchedule` AND `nodeSelector` hostname `cka-labs-m03`.
8. Create pod `no-toleration` (busybox sleep) with `nodeSelector` hostname
   `cka-labs-m03` and NO toleration — it must stay `Pending`.
9. Create deployment `tier-spread` (busybox sleep, 6 replicas, label
   `app=tier-spread`) with a `topologySpreadConstraints`: `maxSkew: 1`,
   `topologyKey: kubernetes.io/hostname`, `whenUnsatisfiable:
   DoNotSchedule`, labelSelector `app=tier-spread`, and
   `nodeTaintsPolicy: Honor` (so the tainted m03 is excluded from the
   domains).
10. Create pod `pinned` (busybox sleep) with `nodeName: cka-labs` —
    bypasses the scheduler entirely.
11. Create PriorityClass `high-prio` (value `100000`, `globalDefault:
    false`) and pod `important` (busybox sleep) with
    `priorityClassName: high-prio`.
12. `kubectl cordon cka-labs-m02`, then save `kubectl get nodes` to
    `~/cka-labs-out/14/nodes.txt`.
13. `kubectl uncordon cka-labs-m02`.

## Verify

```bash
make verify-14
```

## Clean up

```bash
make teardown-14
```

Deletes the namespace, PriorityClass, the `disktype` label and `dedicated`
taint, uncordons all nodes, and the output dir. The worker nodes remain.

## Docs

- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/
