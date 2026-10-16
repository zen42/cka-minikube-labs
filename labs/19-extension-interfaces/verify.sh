#!/usr/bin/env bash
# Lab 19 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

CP="$(control_plane_node)"

# Task 1 — CRI
check_file_contains "nodes.txt lists the node + containerd runtime" \
    "$OUT_DIR/nodes.txt" 'containerd'
check_file_contains "cri-endpoint.txt points at containerd.sock" \
    "$OUT_DIR/cri-endpoint.txt" 'containerd.sock'
check_file_contains "crictl-ps.txt lists running containers" \
    "$OUT_DIR/crictl-ps.txt" 'CONTAINER'
check_file_contains "crictl-images.txt lists images" \
    "$OUT_DIR/crictl-images.txt" 'IMAGE'
check_file_contains "crictl-pods.txt lists kube-system pods" \
    "$OUT_DIR/crictl-pods.txt" 'etcd'

# Task 2 — CNI
check_file_contains "cni-plugin.txt shows calico config" \
    "$OUT_DIR/cni-plugin.txt" 'calico'
check_file_contains "cni-daemonsets.txt shows calico-node" \
    "$OUT_DIR/cni-daemonsets.txt" 'calico-node'

# Task 3 — CSI driver registered + claim bound + pod running
check_file_contains "csi.txt registers hostpath.csi.k8s.io" \
    "$OUT_DIR/csi.txt" 'hostpath.csi.k8s.io'
check "csinode cka-labs reports >= 1 driver" \
    bash -c "kubectl --context $KUBE_CONTEXT get csinode $CP \
        -o json 2>/dev/null | jq -e '.spec.drivers | length >= 1' \
        >/dev/null"
check_jsonpath "pvc csi-claim is Bound" \
    pvc/csi-claim '{.status.phase}' 'Bound' -n ext
check_jsonpath "pod csi-pod is Running" \
    pod/csi-pod '{.status.phase}' 'Running' -n ext
_drv="$(k get pv -o jsonpath='{.items[?(@.spec.claimRef.name=="csi-claim")].spec.csi.driver}' \
    2>/dev/null || true)"
check_eq "PV for csi-claim uses hostpath.csi.k8s.io" \
    "$_drv" 'hostpath.csi.k8s.io'

# Task 4 — snapshot ready
check_jsonpath "volumesnapshot csi-snap is readyToUse" \
    volumesnapshot/csi-snap '{.status.readyToUse}' 'true' -n ext

# Task 5 — kubelet evidence
check_file_contains "kubelet-status.txt shows the unit" \
    "$OUT_DIR/kubelet-status.txt" 'kubelet'
check_file_contains "kubelet-configz.json shows cgroupDriver" \
    "$OUT_DIR/kubelet-configz.json" 'cgroupDriver'
check_file_contains "kubelet-configz.json uses systemd cgroup driver" \
    "$OUT_DIR/kubelet-configz.json" 'systemd'

finish_checks
