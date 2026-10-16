#!/usr/bin/env bash
# Lab 24 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — DNS first: nothing resolves while coredns sits at 0
# replicas (kubectl describe/deploy in kube-system reveals it)
k -n kube-system scale deployment coredns --replicas=1 >/dev/null
wait_for "coredns back up" 240 deploy_available kube-system coredns
wait_for "cluster DNS answering" 120 \
    probe_dns kubernetes.default.svc.cluster.local

# Task 2 — web-svc selects a label no pod has -> zero endpoints
k patch service web-svc -n ts-net --type=json -p \
    '[{"op":"replace","path":"/spec/selector/app","value":"web"}]' \
    >/dev/null
wait_for "web-svc has endpoints" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ts-net get endpoints \
        web-svc -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null \
        | grep -q ."

# Task 3 — api-svc forwards to :80, the pod listens on :8080
k patch service api-svc -n ts-net --type=json -p \
    '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]' \
    >/dev/null

# Task 4 — db-deny-all stays; add a narrow allow for app=client on :80
k apply -n ts-net -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-to-db
spec:
  podSelector:
    matchLabels: {app: db}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels: {app: client}
    ports:
    - {port: 80}
EOF

# Task 5 — ingress points at a service that does not exist
k patch ingress web-ing -n ts-net --type=json -p \
    '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"web-svc"}]' \
    >/dev/null

# Task 6 — kube-proxy + endpointslices evidence
k -n kube-system get ds kube-proxy > "$OUT_DIR/kube-proxy.txt"
k -n kube-system logs ds/kube-proxy --tail=20 \
    > "$OUT_DIR/kube-proxy-log.txt" 2>&1 || true
k get endpointslices -n ts-net > "$OUT_DIR/endpointslices.txt"

info "lab 24 solved"
