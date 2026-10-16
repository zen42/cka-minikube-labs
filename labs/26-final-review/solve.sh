#!/usr/bin/env bash
# Lab 26 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"
CP="$(control_plane_node)"

# Task 1 — deployment shop (create | apply keeps solve re-runnable)
k create deployment shop -n final --image=nginx:1.27 --replicas=3 \
    --dry-run=client -o yaml | k apply -f - >/dev/null
k set resources deployment shop -n final \
    --requests=cpu=50m,memory=64Mi --limits=cpu=200m,memory=128Mi >/dev/null
k patch deployment shop -n final --type=merge -p \
    '{"spec":{"template":{"metadata":{"labels":{"tier":"frontend"}}}}}' \
    >/dev/null
wait_rollout final shop 240s

# Task 2 — services
k expose deployment shop -n final --name=shop-svc --port=80 >/dev/null
k expose deployment shop -n final --name=shop-np --port=80 \
    --type=NodePort >/dev/null
k patch svc shop-np -n final --type=json -p \
    '[{"op":"replace","path":"/spec/ports/0/nodePort","value":30080}]' \
    >/dev/null

# Task 3 — ingress
k create ingress shop-ing -n final --class=nginx \
    --rule='shop.final.local/*=shop-svc:80' >/dev/null

# Task 4 — HPA
k autoscale deployment shop -n final --min=2 --max=5 --cpu=60% >/dev/null

# Task 5 — ConfigMap + Secret via envFrom
k create configmap shop-config -n final --from-literal=THEME=dark \
    --dry-run=client -o yaml | k apply -f - >/dev/null
k create secret generic shop-secret -n final \
    --from-literal=API_KEY=abc123 --dry-run=client -o yaml \
    | k apply -f - >/dev/null
k patch deployment shop -n final --type=json -p \
    '[{"op":"add","path":"/spec/template/spec/containers/0/envFrom","value":[{"configMapRef":{"name":"shop-config"}},{"secretRef":{"name":"shop-secret"}}]}]' \
    >/dev/null
wait_rollout final shop 240s

# Task 6 — PVC + writer pod
k apply -n final -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: final-pvc}
spec:
  storageClassName: manual
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 500Mi}}
---
apiVersion: v1
kind: Pod
metadata: {name: writer}
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh", "-c", "hostname > /data/out.txt; sleep 3600"]
    volumeMounts: [{name: vol, mountPath: /data}]
  volumes:
  - {name: vol, persistentVolumeClaim: {claimName: final-pvc}}
EOF
wait_for "final-pvc bound" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n final get pvc final-pvc \
        -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Bound"
wait_pod_ready final writer 120s

# Task 7 — RBAC
k create serviceaccount deployer -n final \
    --dry-run=client -o yaml | k apply -f - >/dev/null
k create role deploy-manager -n final \
    --verb=get,list,create,update,patch --resource=deployments \
    --dry-run=client -o yaml | k apply -f - >/dev/null
k create rolebinding deploy-manager -n final --role=deploy-manager \
    --serviceaccount=final:deployer \
    --dry-run=client -o yaml | k apply -f - >/dev/null

# Task 8 — NetworkPolicy
k apply -n final -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: shop-allow-ingress-only}
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
EOF

# Task 9 — CronJob + a manual run
k create cronjob report -n final --image=busybox:1.36 \
    --schedule='*/10 * * * *' --dry-run=client -o yaml \
    | k apply -f - >/dev/null
k patch cronjob report -n final --type=json -p \
    '[{"op":"add","path":"/spec/successfulJobsHistoryLimit","value":2}]' \
    >/dev/null
k delete job report-manual -n final --ignore-not-found >/dev/null
k create job --from=cronjob/report report-manual -n final >/dev/null
k wait --for=condition=complete job/report-manual -n final \
    --timeout=90s >/dev/null

# Task 10 — fix legacy
k set image deployment/legacy web=httpd:2.4 -n final >/dev/null
wait_rollout final legacy 240s

# Task 11 — node label + scheduling
k label node "$CP" zone=a --overwrite >/dev/null
k patch deployment shop -n final --type=json -p \
    '[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"zone":"a"}}]' \
    >/dev/null
wait_rollout final shop 240s

# Task 12 — etcd snapshot + final inventory
node_ssh "$CP" "sudo mkdir -p /var/lib/minikube/etcd-backup \
    && sudo ETCDCTL_API=3 /usr/local/bin/etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/var/lib/minikube/certs/etcd/ca.crt \
        --cert=/var/lib/minikube/certs/etcd/server.crt \
        --key=/var/lib/minikube/certs/etcd/server.key \
        snapshot save /var/lib/minikube/etcd-backup/final.db" >/dev/null
node_ssh "$CP" \
    "sudo /usr/local/bin/etcdutl snapshot status \
        /var/lib/minikube/etcd-backup/final.db -w table" \
    > "$OUT_DIR/etcd-status.txt"
k get all -n final -o wide > "$OUT_DIR/final-state.txt"

info "lab 26 solved"
