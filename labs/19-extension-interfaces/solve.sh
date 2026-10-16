#!/usr/bin/env bash
# Lab 19 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

CP="$(control_plane_node)"

# Task 1 — CRI: node list, containerd endpoint, crictl inventory
k get nodes -o wide > "$OUT_DIR/nodes.txt"
node_ssh "$CP" \
    "sudo grep containerRuntimeEndpoint /var/lib/kubelet/config.yaml" \
    > "$OUT_DIR/cri-endpoint.txt"
node_ssh "$CP" "sudo crictl ps" > "$OUT_DIR/crictl-ps.txt"
node_ssh "$CP" "sudo crictl images" > "$OUT_DIR/crictl-images.txt"
node_ssh "$CP" "sudo crictl pods --namespace kube-system" \
    > "$OUT_DIR/crictl-pods.txt"

# Task 2 — CNI: which plugin is configured on the node + calico DaemonSet
{ node_ssh "$CP" "ls /etc/cni/net.d/"
  node_ssh "$CP" \
      "sudo grep '\"name\"' /etc/cni/net.d/*.conflist | head -2"
} > "$OUT_DIR/cni-plugin.txt"
k -n kube-system get ds > "$OUT_DIR/cni-daemonsets.txt"

# Task 3 — CSI: enable the hostpath driver + a real claim
mk addons enable volumesnapshots >/dev/null
mk addons enable csi-hostpath-driver >/dev/null
wait_for "csi-hostpathplugin ready" 300 \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pod \
        -l kubernetes.io/minikube-addons=csi-hostpath-driver \
        --no-headers 2>/dev/null | grep -q ' Running ' || \
        kubectl --context $KUBE_CONTEXT -n kube-system get sts \
        csi-hostpathplugin -o jsonpath='{.status.readyReplicas}' \
        2>/dev/null | grep -qE '^[1-9]'"
k get csidrivers,csinodes > "$OUT_DIR/csi.txt"
k apply -n ext -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-claim
spec:
  storageClassName: csi-hostpath-sc
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: csi-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: csi-claim
EOF
wait_for "pvc csi-claim Bound" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ext get pvc csi-claim \
        -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Bound"
wait_pod_ready ext csi-pod 180s

# Task 4 — snapshot the claim
k apply -n ext -f - >/dev/null <<'EOF'
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: csi-snap
spec:
  volumeSnapshotClassName: csi-hostpath-snapclass
  source:
    persistentVolumeClaimName: csi-claim
EOF
wait_for "volumesnapshot csi-snap readyToUse" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ext get volumesnapshot \
        csi-snap -o jsonpath='{.status.readyToUse}' 2>/dev/null \
        | grep -q true"

# Task 5 — kubelet: unit status, journal, and live config via the
# apiserver's node proxy
node_ssh "$CP" "sudo systemctl status kubelet --no-pager" \
    > "$OUT_DIR/kubelet-status.txt" 2>&1 || true
node_ssh "$CP" "sudo journalctl -u kubelet --no-pager -n 50" \
    > "$OUT_DIR/kubelet-journal.txt" 2>&1 || true
k get --raw "/api/v1/nodes/$CP/proxy/configz" | jq . \
    > "$OUT_DIR/kubelet-configz.json"

info "lab 19 solved"
