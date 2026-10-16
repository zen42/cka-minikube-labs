# Lab 12 – Solution

### Task 1

```bash
kubectl apply -f - <<'EOF'
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
```

### Task 2

```bash
kubectl apply -n storage -f - <<'EOF'
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
kubectl get pvc claim-manual -n storage   # Bound to pv-manual
```

Why: the binder picks any PV that satisfies the request — a 500Mi claim
can bind a 1Gi volume.

### Task 3

```bash
kubectl apply -n storage -f - <<'EOF'
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
```

### Task 4

```bash
kubectl delete pod writer -n storage --wait=true
kubectl apply -n storage -f - <<'EOF'
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
kubectl wait --for=condition=Ready pod/reader -n storage --timeout=120s
kubectl exec reader -n storage -- cat /data/msg.txt \
    > ~/cka-labs-out/12/msg.txt
```

### Task 5

```bash
kubectl apply -f - <<'EOF'
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
kubectl get pvc claim-broken -n storage   # now Bound
```

Why: `claim-broken` wants 5Gi + ReadWriteMany + class `manual` — only a PV
matching all three binds.

### Task 6

```bash
kubectl apply -f - <<'EOF'
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
```

### Task 7

```bash
kubectl apply -f - <<'EOF'
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
  resources:
    requests:
      storage: 1Gi
EOF
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
    pvc/claim-delete -n storage --timeout=60s
kubectl delete pvc claim-delete -n storage
kubectl get pv pv-delete   # Delete on a hostPath PV can't delete the dir
kubectl get pv pv-delete -o jsonpath='{.status.phase}' \
    > ~/cka-labs-out/12/pv-delete-status.txt
```

Why: reclaim `Delete` asks the volume plugin to remove the backing data —
the hostPath plugin can't do that for static volumes, so the PV ends up
`Failed` rather than deleted.

### Task 8

```bash
kubectl get pv --sort-by=.spec.capacity.storage \
    > ~/cka-labs-out/12/pvs.txt
```

### Task 9

```bash
kubectl apply -n storage -f - <<'EOF'
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
```
