# Lab 26 – Solution

`$OUT` is `~/cka-labs-out/26`. All objects live in namespace `final`.

### Task 1

```bash
kubectl create deployment shop -n final --image=nginx:1.27 --replicas=3
kubectl set resources deployment shop -n final \
    --requests=cpu=50m,memory=64Mi --limits=cpu=200m,memory=128Mi
kubectl patch deployment shop -n final --type=merge -p \
    '{"spec":{"template":{"metadata":{"labels":{"tier":"frontend"}}}}}'
```

### Task 2

```bash
kubectl expose deployment shop -n final --name=shop-svc --port=80
kubectl expose deployment shop -n final --name=shop-np --port=80 \
    --type=NodePort
kubectl patch svc shop-np -n final --type=json -p \
    '[{"op":"replace","path":"/spec/ports/0/nodePort","value":30080}]'
# expose picks a random nodePort — patch it to the required 30080
```

### Task 3

```bash
kubectl create ingress shop-ing -n final --class=nginx \
    --rule='shop.final.local/*=shop-svc:80'
kubectl run probe --rm -i --restart=Never --image=busybox:1.36 \
    -- wget -qO- --header 'Host: shop.final.local' \
    http://ingress-nginx-controller.ingress-nginx
```

### Task 4

```bash
kubectl autoscale deployment shop -n final --min=2 --max=5 --cpu=60%
```

### Task 5

```bash
kubectl create configmap shop-config -n final --from-literal=THEME=dark
kubectl create secret generic shop-secret -n final \
    --from-literal=API_KEY=abc123
kubectl patch deployment shop -n final --type=json -p '[{"op":"add",
 "path":"/spec/template/spec/containers/0/envFrom","value":[
  {"configMapRef":{"name":"shop-config"}},
  {"secretRef":{"name":"shop-secret"}}]}]'
kubectl exec deploy/shop -n final -- printenv THEME   # dark
```

### Task 6

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: final-pvc, namespace: final}
spec:
  storageClassName: manual          # match the PV's class
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 500Mi}}
---
apiVersion: v1
kind: Pod
metadata: {name: writer, namespace: final}
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh","-c","hostname > /data/out.txt; sleep 3600"]
    volumeMounts: [{name: vol, mountPath: /data}]
  volumes: [{name: vol, persistentVolumeClaim: {claimName: final-pvc}}]
```

### Task 7

```bash
kubectl create serviceaccount deployer -n final
kubectl create role deploy-manager -n final \
    --verb=get,list,create,update,patch --resource=deployments
kubectl create rolebinding deploy-manager -n final \
    --role=deploy-manager --serviceaccount=final:deployer
kubectl auth can-i create deployments \
    --as=system:serviceaccount:final:deployer -n final   # yes
kubectl auth can-i delete deployments \
    --as=system:serviceaccount:final:deployer -n final   # no
```

### Task 8

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: shop-allow-ingress-only, namespace: final}
spec:
  podSelector: {matchLabels: {tier: frontend}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels: {kubernetes.io/metadata.name: ingress-nginx}
    - podSelector:
        matchLabels: {access: shop}
    ports: [{port: 80}]
# the two `from` items are OR'd; ports applies to both
```

### Task 9

```bash
kubectl create cronjob report -n final --image=busybox:1.36 \
    --schedule='*/10 * * * *' -- date
kubectl patch cronjob report -n final --type=json -p \
    '[{"op":"add","path":"/spec/successfulJobsHistoryLimit","value":2}]'
kubectl create job --from=cronjob/report report-manual -n final
kubectl wait --for=condition=complete job/report-manual -n final \
    --timeout=90s
```

### Task 10

```bash
kubectl describe deployment legacy -n final   # image httpd:2.4-typo
kubectl set image deployment/legacy web=httpd:2.4 -n final
kubectl rollout status deploy/legacy -n final
```

### Task 11

```bash
kubectl label node cka-labs zone=a
kubectl patch deployment shop -n final --type=json -p '[{"op":"add",
 "path":"/spec/template/spec/nodeSelector","value":{"zone":"a"}}]'
kubectl rollout status deploy/shop -n final
```

### Task 12

```bash
minikube -p cka-labs ssh
sudo mkdir -p /var/lib/minikube/etcd-backup
sudo ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/var/lib/minikube/certs/etcd/ca.crt \
    --cert=/var/lib/minikube/certs/etcd/server.crt \
    --key=/var/lib/minikube/certs/etcd/server.key \
    snapshot save /var/lib/minikube/etcd-backup/final.db
sudo etcdutl snapshot status /var/lib/minikube/etcd-backup/final.db \
    -w table > /tmp/etcd-status.txt
# copy it out (or re-run with the host redirecting stdout)
kubectl get all -n final -o wide > $OUT/final-state.txt
```
