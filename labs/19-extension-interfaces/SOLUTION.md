# Lab 19 – Solution

All node-side commands run inside `minikube -p cka-labs ssh` and need
`sudo`. `$OUT` is `~/cka-labs-out/19`.

### Task 1

```bash
kubectl get nodes -o wide > $OUT/nodes.txt
minikube -p cka-labs ssh -- \
    'sudo grep containerRuntimeEndpoint /var/lib/kubelet/config.yaml' \
    > $OUT/cri-endpoint.txt
minikube -p cka-labs ssh -- 'sudo crictl ps'      > $OUT/crictl-ps.txt
minikube -p cka-labs ssh -- 'sudo crictl images'  > $OUT/crictl-images.txt
minikube -p cka-labs ssh -- \
    'sudo crictl pods --namespace kube-system'    > $OUT/crictl-pods.txt
```

Why: the kubelet's `containerRuntimeEndpoint`
(`unix:///run/containerd/containerd.sock`) is the CRI socket `crictl`
talks to by default.

### Task 2

```bash
minikube -p cka-labs ssh -- 'ls /etc/cni/net.d/' > $OUT/cni-plugin.txt
minikube -p cka-labs ssh -- \
    'sudo grep "\"name\"" /etc/cni/net.d/*.conflist | head -2' \
    >> $OUT/cni-plugin.txt
kubectl -n kube-system get ds > $OUT/cni-daemonsets.txt
```

Why: this cluster uses Calico (`10-calico.conflist`); the per-node CNI
work runs as the `calico-node` DaemonSet.

### Task 3

```bash
minikube -p cka-labs addons enable volumesnapshots
minikube -p cka-labs addons enable csi-hostpath-driver
kubectl -n kube-system rollout status statefulset/csi-hostpathplugin
kubectl get csidrivers,csinodes > $OUT/csi.txt
kubectl apply -n ext -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: csi-claim}
spec:
  storageClassName: csi-hostpath-sc
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 100Mi}}
---
apiVersion: v1
kind: Pod
metadata: {name: csi-pod}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts: [{name: data, mountPath: /data}]
  volumes:
  - name: data
    persistentVolumeClaim: {claimName: csi-claim}
EOF
kubectl -n ext wait --for=jsonpath='{.status.phase}'=Bound \
    pvc/csi-claim --timeout=120s
kubectl -n ext wait --for=condition=Ready pod/csi-pod --timeout=180s
```

### Task 4

```bash
kubectl apply -n ext -f - <<'EOF'
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: {name: csi-snap}
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source: {persistentVolumeClaimName: csi-claim}
EOF
kubectl -n ext wait --for=jsonpath='{.status.readyToUse}'=true \
    volumesnapshot/csi-snap --timeout=180s
```

### Task 5

```bash
minikube -p cka-labs ssh -- 'sudo systemctl status kubelet --no-pager' \
    > $OUT/kubelet-status.txt
minikube -p cka-labs ssh -- \
    'sudo journalctl -u kubelet --no-pager -n 50' \
    > $OUT/kubelet-journal.txt
kubectl get --raw /api/v1/nodes/cka-labs/proxy/configz | jq . \
    > $OUT/kubelet-configz.json
```

Why: `/configz` is the kubelet's live merged config — you can see
`containerRuntimeEndpoint` and `cgroupDriver: systemd` without ssh.
