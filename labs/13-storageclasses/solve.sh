#!/usr/bin/env bash
# Lab 13 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

pvc_bound() {
    [[ "$(k get pvc "$1" -n dynamic \
        -o jsonpath='{.status.phase}' 2>/dev/null)" == "Bound" ]]
}

# Task 1 — save SC listing + the default class name
k get sc > "$OUT_DIR/storageclasses.txt"
k get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' \
    > "$OUT_DIR/default-sc.txt"
echo >> "$OUT_DIR/default-sc.txt"

# Task 2 — claim-dynamic on the default class
k apply -n dynamic -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-dynamic
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
wait_for "claim-dynamic Bound" 120 pvc_bound claim-dynamic

# Task 3 — StorageClass fast
k apply -f - >/dev/null <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

# Task 4 — slow-wait (WaitForFirstConsumer) + claim-wait
k apply -f - >/dev/null <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow-wait
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-wait
  namespace: dynamic
spec:
  storageClassName: slow-wait
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
sleep 8
info "claim-wait phase before consumer: \
$(k get pvc claim-wait -n dynamic -o jsonpath='{.status.phase}')"

# Task 5 — consumer pod + unstick the provisioner.
# WFFC binding needs the provisioner to read the node the scheduler picked,
# but minikube's storage-provisioner SA cannot 'get nodes' — describe the
# PVC to see ProvisioningFailed, then grant it (the class stays untouched).
k apply -n dynamic -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: consumer
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
      claimName: claim-wait
EOF
sleep 5
k describe pvc claim-wait -n dynamic 2>/dev/null \
    | grep -i 'provisioning' || true
k create clusterrole storage-provisioner-nodes \
    --verb=get,list --resource=nodes 2>/dev/null \
    || k get clusterrole storage-provisioner-nodes >/dev/null
k create clusterrolebinding storage-provisioner-nodes \
    --clusterrole=storage-provisioner-nodes \
    --serviceaccount=kube-system:storage-provisioner 2>/dev/null \
    || k get clusterrolebinding storage-provisioner-nodes >/dev/null
wait_for "claim-wait Bound" 120 pvc_bound claim-wait
wait_pod_ready dynamic consumer 120s

# Task 6 — fast becomes the default; standard does not (patch the legacy
# beta annotation too — the admission plugin still honors it)
k patch storageclass standard --type=merge -p \
    '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false","storageclass.beta.kubernetes.io/is-default-class":"false"}}}' \
    >/dev/null
k patch storageclass fast --type=merge -p \
    '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true","storageclass.beta.kubernetes.io/is-default-class":"true"}}}' \
    >/dev/null

# Task 7 — claim-fast lands on fast
k apply -n dynamic -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-fast
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
wait_for "claim-fast Bound" 120 pvc_bound claim-fast

# Task 8 — expand claim-fast to 2Gi
k patch pvc claim-fast -n dynamic --type=merge -p \
    '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}' >/dev/null

# Task 9 — keep SC (Retain) + claim-retain; delete → Released PV
k apply -f - >/dev/null <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: keep
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-retain
  namespace: dynamic
spec:
  storageClassName: keep
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF
wait_for "claim-retain Bound" 120 pvc_bound claim-retain
k delete pvc claim-retain -n dynamic --wait=true >/dev/null
wait_for "released PV for claim-retain" 90 \
    bash -c "kubectl --context $KUBE_CONTEXT get pv \
        -o jsonpath='{.items[?(@.spec.claimRef.name==\"claim-retain\")].status.phase}' \
        2>/dev/null | grep -q Released"

# Task 10 — PV backing claim-dynamic to file
k get pvc claim-dynamic -n dynamic -o jsonpath='{.spec.volumeName}' \
    > "$OUT_DIR/claim-dynamic-pv.txt"
echo >> "$OUT_DIR/claim-dynamic-pv.txt"

info "lab 13 solved"
