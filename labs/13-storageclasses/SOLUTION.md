# Lab 13 – Solution

### Task 1

```bash
kubectl get sc > ~/cka-labs-out/13/storageclasses.txt
kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' \
    > ~/cka-labs-out/13/default-sc.txt
```

### Task 2

```bash
kubectl apply -n dynamic -f - <<'EOF'
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
kubectl get pvc claim-dynamic -n dynamic
kubectl get pv
```

Why: with no `storageClassName`, the admission controller fills in the
default class (`standard`).

### Task 3

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF
```

### Task 4

```bash
kubectl apply -f - <<'EOF'
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
kubectl get pvc claim-wait -n dynamic   # Pending until a consumer exists
```

Why: `WaitForFirstConsumer` defers provisioning until a pod using the
claim is scheduled — that's how topology-aware provisioning works.

### Task 5

```bash
kubectl apply -n dynamic -f - <<'EOF'
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
kubectl describe pvc claim-wait -n dynamic
# Events: ProvisioningFailed — User "system:serviceaccount:kube-system:
# storage-provisioner" cannot get resource "nodes"
kubectl create clusterrole storage-provisioner-nodes \
    --verb=get,list --resource=nodes
kubectl create clusterrolebinding storage-provisioner-nodes \
    --clusterrole=storage-provisioner-nodes \
    --serviceaccount=kube-system:storage-provisioner
kubectl get pvc claim-wait -n dynamic   # Bound now
```

Why: deferred binding means the provisioner only acts once the scheduler
has chosen a node — and it must GET that node to place the hostPath.
minikube's `storage-provisioner` ServiceAccount lacks node read access,
so the claim loops `ProvisioningFailed` until a ClusterRole grants
`get`/`list` on `nodes`.

### Task 6

```bash
kubectl patch storageclass standard --type=merge -p \
    '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false","storageclass.beta.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass fast --type=merge -p \
    '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true","storageclass.beta.kubernetes.io/is-default-class":"true"}}}'
kubectl get sc   # exactly one (default)
```

### Task 7

```bash
kubectl apply -n dynamic -f - <<'EOF'
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
kubectl get pvc claim-fast -n dynamic -o jsonpath='{.spec.storageClassName}'
# fast
```

### Task 8

```bash
kubectl patch pvc claim-fast -n dynamic --type=merge -p \
    '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
kubectl get pvc claim-fast -n dynamic   # spec 2Gi; .status may lag
```

### Task 9

```bash
kubectl apply -f - <<'EOF'
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
kubectl delete pvc claim-retain -n dynamic
kubectl get pv   # the released PV shows Released
```

Why: `Retain` keeps the PV (and its data) after the claim is gone — it
must be reclaimed manually.

### Task 10

```bash
kubectl get pvc claim-dynamic -n dynamic \
    -o jsonpath='{.spec.volumeName}' \
    > ~/cka-labs-out/13/claim-dynamic-pv.txt
```
