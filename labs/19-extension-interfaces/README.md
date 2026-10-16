# Lab 19 – Extension Interfaces (CRI / CNI / CSI)

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 18

Where Kubernetes hands off to the node: inspect the container runtime
endpoint (CRI), the CNI config, enable a real CSI driver and use it for a
persistent volume and a VolumeSnapshot, and pull the kubelet's live
config through the apiserver proxy.

## Objectives

- `crictl` against containerd inside the node
- CNI config under `/etc/cni/net.d/` (Calico here)
- minikube's `csi-hostpath-driver` + `volumesnapshots` addons
- PVC on a CSI StorageClass, VolumeSnapshot lifecycle
- kubelet: systemd unit + `/api/v1/nodes/<node>/proxy/configz`

## Environment

- **Namespace:** `ext`.
- **Output dir:** `~/cka-labs-out/19/`
- **Start here:** `make lab-19`
- Node access: `minikube -p cka-labs ssh` — `crictl` and the CNI config
  live *inside* the node and need `sudo`.
- The CSI work uses two minikube addons (`volumesnapshots` first, then
  `csi-hostpath-driver`). They provision StorageClass `csi-hostpath-sc`
  and VolumeSnapshotClass `csi-hostpath-snapclass`.

## Tasks

1. Save `kubectl get nodes -o wide` to `~/cka-labs-out/19/nodes.txt`.
   Inside the node, record the kubelet's `containerRuntimeEndpoint`
   (from `/var/lib/kubelet/config.yaml`) to
   `~/cka-labs-out/19/cri-endpoint.txt`, and save `crictl ps`,
   `crictl images`, and `crictl pods --namespace kube-system` to
   `crictl-ps.txt`, `crictl-images.txt`, `crictl-pods.txt`.
2. CNI: save `ls /etc/cni/net.d/` plus the `"name"` of the installed
   conflist to `~/cka-labs-out/19/cni-plugin.txt`, and
   `kubectl -n kube-system get ds` to
   `~/cka-labs-out/19/cni-daemonsets.txt`.
3. CSI: `minikube -p cka-labs addons enable volumesnapshots`, then
   `... enable csi-hostpath-driver`. Save
   `kubectl get csidrivers,csinodes` to `~/cka-labs-out/19/csi.txt`.
   Create PVC `csi-claim` (100Mi, storageClassName `csi-hostpath-sc`)
   and pod `csi-pod` mounting it at `/data`.
4. Create `VolumeSnapshot` `csi-snap` of `csi-claim` using
   `volumeSnapshotClassName: csi-hostpath-snapclass` and wait until
   `readyToUse` is true.
5. Kubelet: save `systemctl status kubelet` to
   `~/cka-labs-out/19/kubelet-status.txt`, the last 50 journal lines to
   `~/cka-labs-out/19/kubelet-journal.txt`, and
   `kubectl get --raw /api/v1/nodes/cka-labs/proxy/configz | jq .`
   to `~/cka-labs-out/19/kubelet-configz.json`.

## Verify

```bash
make verify-19
```

## Clean up

```bash
make teardown-19
```

Deletes the snapshot/pod/PVC/namespace and disables both addons.

## Docs

- https://kubernetes.io/docs/concepts/architecture/cri/
- https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- https://kubernetes.io/docs/concepts/storage/volume-snapshots/
- https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
