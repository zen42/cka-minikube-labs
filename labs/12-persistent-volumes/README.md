# Lab 12 – Persistent Volumes & Claims

**Domain:** Storage (10%) · **Builds on:** Lab 02

Static provisioning: `PersistentVolume` ↔ `PersistentVolumeClaim` binding,
access modes, `storageClassName`, reclaim policies, `emptyDir`.

## Objectives

- `hostPath` PVs, PVC binding rules (size, access mode, class, selectors)
- Data persistence across pod deletion
- `persistentVolumeReclaimPolicy` Retain vs Delete
- `emptyDir` incl. `medium: Memory`

## Environment

- **Namespace:** `storage`, with a PVC `claim-broken` (5Gi, ReadWriteMany,
  class `manual`) seeded — it stays `Pending` because no matching PV exists.
- **Output dir:** `~/cka-labs-out/12/`
- **Start here:** `make lab-12`
- `hostPath` PVs are node-local: give every one you create here a
  `spec.nodeAffinity` that requires `kubernetes.io/hostname In [cka-labs]`
  so consumer pods always land on the node where the directory lives —
  that's what `local` PVs use node affinity for on multi-node clusters.
- A PVC binds to the smallest PV that satisfies size + access mode + class.
  A 500Mi claim happily binds a 1Gi volume.

## Tasks

1. Create PV `pv-manual`: `hostPath` `/mnt/data/pv-manual`, capacity `1Gi`,
   access mode `ReadWriteOnce`, `storageClassName: manual`,
   `persistentVolumeReclaimPolicy: Retain`, and `spec.nodeAffinity`
   pinning it to `kubernetes.io/hostname=cka-labs`.
2. Create PVC `claim-manual` requesting `500Mi`, `ReadWriteOnce`, class
   `manual`. Confirm it binds to `pv-manual`.
3. Create pod `writer` (busybox) mounting `claim-manual` at `/data` and
   running `sh -c 'echo "hello from writer" > /data/msg.txt && sleep 3600'`.
4. Delete `writer`, then create pod `reader` mounting the same claim. Read
   `/data/msg.txt` in `reader` and save it to
   `~/cka-labs-out/12/msg.txt`.
5. `claim-broken` is still `Pending` — fix it by creating PV `pv-shared`:
   `hostPath` `/mnt/data/pv-shared`, `5Gi`, `ReadWriteMany`, class `manual`,
   reclaim `Retain`, same `nodeAffinity` as task 1.
6. Create PV `pv-labeled` (`hostPath` `/mnt/data/pv-labeled`, `1Gi`, RWO,
   `manual`, label `tier=gold`, same `nodeAffinity`) and PVC `claim-gold`
   with a
   `selector.matchLabels` of `tier=gold`. Confirm it binds `pv-labeled`
   specifically.
7. Create PV `pv-delete` (`hostPath` `/mnt/data/pv-delete`, `1Gi`, RWO,
   `manual`, reclaim `Delete`, same `nodeAffinity`) and PVC `claim-delete`
   bound to it; then
   delete `claim-delete` and record `pv-delete`'s resulting `STATUS` to
   `~/cka-labs-out/12/pv-delete-status.txt`.
8. Save `kubectl get pv --sort-by=.spec.capacity.storage` to
   `~/cka-labs-out/12/pvs.txt`.
9. Create pod `scratch` (busybox `sleep 3600`) with an `emptyDir` volume
   (`medium: Memory`, `sizeLimit: 100Mi`) mounted at `/cache`.

## Verify

```bash
make verify-12
```

## Clean up

```bash
make teardown-12
```

Deletes the namespace, the PVs, the hostPath dirs inside the node, and the
output dir.

## Docs

- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/
- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
