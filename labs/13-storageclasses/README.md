# Lab 13 – StorageClasses & Dynamic Provisioning

**Domain:** Storage (10%) · **Builds on:** Lab 12

Dynamic provisioning: `StorageClass` objects, the default class,
`volumeBindingMode`, expansion, and reclaim behavior.

## Objectives

- Default StorageClass + `storageclass.kubernetes.io/is-default-class`
- `k8s.io/minikube-hostpath` provisioner; Immediate vs
  `WaitForFirstConsumer`
- `allowVolumeExpansion`, PVC resize, reclaim `Retain` → `Released`

## Environment

- **Namespace:** `dynamic`.
- **Output dir:** `~/cka-labs-out/13/`
- **Start here:** `make lab-13`
- Minikube's `standard` class uses provisioner
  `k8s.io/minikube-hostpath` (addons `storage-provisioner` +
  `default-storageclass`). setup.sh backs it up to `.state/` — teardown
  restores its annotations.
- Provisioner quirks to observe while you work:
  - `WaitForFirstConsumer` defers provisioning until the scheduler picks
    a node for the consuming pod — and the provisioner must then READ
    that node to place the hostPath. minikube's `storage-provisioner`
    ServiceAccount cannot `get nodes` by default, so the claim stays
    `Pending` until you grant it (task 5).
  - PVC expansion updates the claim's `spec`; whether `.status.capacity`
    follows depends on the provisioner.

## Tasks

1. Save `kubectl get sc` to `~/cka-labs-out/13/storageclasses.txt` and
   write the name of the default StorageClass to
   `~/cka-labs-out/13/default-sc.txt`.
2. Create PVC `claim-dynamic` (1Gi, RWO) with NO `storageClassName` — let
   the default class provision it. Confirm it binds and note the PV.
3. Create StorageClass `fast`: provisioner `k8s.io/minikube-hostpath`,
   `reclaimPolicy: Delete`, `volumeBindingMode: Immediate`,
   `allowVolumeExpansion: true`.
4. Create StorageClass `slow-wait` with the same provisioner but
   `volumeBindingMode: WaitForFirstConsumer`, and PVC `claim-wait` (1Gi,
   RWO) on it. It stays `Pending` until a consumer exists.
5. Create pod `consumer` (busybox `sleep 3600`) that mounts `claim-wait`
   — the pod AND the claim stay `Pending`. Find out why
   (`kubectl describe pvc claim-wait`, look at the events) and fix it
   WITHOUT changing the StorageClass: grant the `storage-provisioner`
   ServiceAccount in `kube-system` permission to `get`/`list` `nodes`
   via a ClusterRole `storage-provisioner-nodes` and a ClusterRoleBinding
   of the same name. Once the provisioner can see the selected node, the
   claim binds.
6. Make `fast` the default class and un-default `standard`: set the
   annotation `storageclass.kubernetes.io/is-default-class` to `"false"`
   on `standard` (do not just delete it) and `"true"` on `fast`, e.g. via
   `kubectl patch`/`annotate --overwrite`. Exactly one class may be
   default.
7. Create PVC `claim-fast` (1Gi, RWO) with no `storageClassName` — it must
   land on `fast`.
8. Expand `claim-fast` to `2Gi` by editing its
   `spec.resources.requests.storage`.
9. Create StorageClass `keep` (`k8s.io/minikube-hostpath`, reclaim
   `Retain`) and PVC `claim-retain` (1Gi, RWO) on it; then delete the PVC
   and observe the released PV go to `Released`.
10. Write the name of the PV backing `claim-dynamic` to
    `~/cka-labs-out/13/claim-dynamic-pv.txt`.

## Verify

```bash
make verify-13     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-13   # from the repo root — or ./teardown.sh in this directory
```

Deletes the namespace, the `fast`/`slow-wait`/`keep` classes, the
`storage-provisioner-nodes` ClusterRole/ClusterRoleBinding, leftover
`Released` PVs from this lab, restores `standard`'s annotations, and the
output dir.

## Docs

- https://kubernetes.io/docs/concepts/storage/storage-classes/
- https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims
