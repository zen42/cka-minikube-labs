#!/usr/bin/env bash
# Lab 12 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

pvc_bound() {
    [[ "$(k get pvc "$1" -n storage \
        -o jsonpath='{.status.phase}' 2>/dev/null)" == "Bound" ]]
}

# Task 1 — pv-manual
k apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-manual
spec:
  storageClassName: manual
  persistentVolumeReclaimPolicy: Retain
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  hostPath:
    path: /mnt/data/pv-manual
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["cka-labs"]
EOF

# Task 2 — claim-manual binds pv-manual
k apply -n storage -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-manual
spec:
  storageClassName: manual
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 500Mi
EOF
wait_for "claim-manual Bound" 60 pvc_bound claim-manual

# Task 3 — writer pod
k apply -n storage -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'hello from writer' > /data/msg.txt && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: claim-manual
EOF
wait_pod_ready storage writer 120s

# Task 4 — delete writer, reader reads the same data
k delete pod writer -n storage --wait=true >/dev/null
k apply -n storage -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: reader
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
      claimName: claim-manual
EOF
wait_pod_ready storage reader 120s
k exec reader -n storage -- cat /data/msg.txt > "$OUT_DIR/msg.txt"

# Task 5 — pv-shared satisfies claim-broken (5Gi RWX manual)
k apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-shared
spec:
  storageClassName: manual
  persistentVolumeReclaimPolicy: Retain
  capacity:
    storage: 5Gi
  accessModes: [ReadWriteMany]
  hostPath:
    path: /mnt/data/pv-shared
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["cka-labs"]
EOF
wait_for "claim-broken Bound" 60 pvc_bound claim-broken

# Task 6 — pv-labeled + claim-gold with a selector
k apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-labeled
  labels:
    tier: gold
spec:
  storageClassName: manual
  persistentVolumeReclaimPolicy: Retain
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  hostPath:
    path: /mnt/data/pv-labeled
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["cka-labs"]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-gold
  namespace: storage
spec:
  storageClassName: manual
  accessModes: [ReadWriteOnce]
  selector:
    matchLabels:
      tier: gold
  resources:
    requests:
      storage: 1Gi
EOF
wait_for "claim-gold Bound" 60 pvc_bound claim-gold

# Task 7 — Delete reclaim on a hostPath PV → Failed after PVC deletion
k apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-delete
spec:
  storageClassName: manual
  persistentVolumeReclaimPolicy: Delete
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  hostPath:
    path: /mnt/data/pv-delete
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["cka-labs"]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-delete
  namespace: storage
spec:
  storageClassName: manual
  accessModes: [ReadWriteOnce]
  volumeName: pv-delete
  resources:
    requests:
      storage: 1Gi
EOF
wait_for "claim-delete Bound" 60 pvc_bound claim-delete
k delete pvc claim-delete -n storage >/dev/null
wait_for "pv-delete leaves Bound state" 90 \
    bash -c "s=\$(kubectl --context $KUBE_CONTEXT get pv pv-delete \
        -o jsonpath='{.status.phase}' 2>/dev/null); \
        [[ -n \"\$s\" && \"\$s\" != Bound ]]"
k get pv pv-delete -o jsonpath='{.status.phase}' \
    > "$OUT_DIR/pv-delete-status.txt"
echo >> "$OUT_DIR/pv-delete-status.txt"

# Task 8 — PVs sorted by capacity
k get pv --sort-by=.spec.capacity.storage > "$OUT_DIR/pvs.txt"

# Task 9 — scratch pod with in-memory emptyDir
k apply -n storage -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: scratch
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir:
      medium: Memory
      sizeLimit: 100Mi
EOF
wait_pod_ready storage scratch 120s

info "lab 12 solved"
