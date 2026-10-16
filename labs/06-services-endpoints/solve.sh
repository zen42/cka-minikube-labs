#!/usr/bin/env bash
# Lab 06 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — deployment web (busybox httpd, token "web") + ClusterIP svc
k create deployment web --image=busybox:1.36 --replicas=3 -n services \
    --dry-run=client -o yaml \
    -- sh -c 'mkdir -p /www && echo web > /www/index.html \
              && httpd -f -p 80 -h /www' | k apply -f - >/dev/null
wait_rollout services web 180s
k expose deployment web -n services --name=web-svc \
    --port=80 --target-port=80 --dry-run=client -o yaml \
    | k apply -f - >/dev/null

# Task 2 — NodePort 30080
k apply -n services -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector: {app: web}
  ports:
  - {port: 80, targetPort: 80, nodePort: 30080}
EOF

# Task 3 — LoadBalancer (EXTERNAL-IP stays <pending> on minikube)
k apply -n services -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-lb
spec:
  type: LoadBalancer
  selector: {app: web}
  ports:
  - {port: 80, targetPort: 80}
EOF

# Task 4 — fix legacy-svc selector typo
k patch svc legacy-svc -n services \
    -p '{"spec":{"selector":{"app":"legacy-api"}}}' >/dev/null
wait_for "legacy-svc has endpoints" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT -n services get endpoints \
        legacy-svc --no-headers 2>/dev/null | grep -q '[0-9]'"

# Task 5 — headless service
k apply -n services -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  selector: {app: web}
  ports:
  - {port: 80, targetPort: 80}
EOF

# Task 6 — ExternalName
k apply -n services -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
  ports:
  - {port: 5432}
EOF

# Task 7 — selectorless service + hand-written EndpointSlice
k apply -n services -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: manual-svc
spec:
  ports:
  - {port: 8080, targetPort: 80}
EOF
POD_IP="$(k get pod -n services -l app=web \
    -o jsonpath='{.items[0].status.podIP}')"
k apply -n services -f - >/dev/null <<EOF
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: manual-svc-1
  labels:
    kubernetes.io/service-name: manual-svc
addressType: IPv4
endpoints:
  - addresses: ["$POD_IP"]
    conditions:
      ready: true
ports:
  - {port: 80, protocol: TCP}
EOF

# Task 8 — save EndpointSlices of web-svc
wait_for "web-svc EndpointSlice exists" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT -n services get endpointslices \
        -l kubernetes.io/service-name=web-svc --no-headers 2>/dev/null | grep -q ."
k get endpointslices -n services \
    -l kubernetes.io/service-name=web-svc -o wide \
    > "$OUT_DIR/web-endpoints.txt"

# Task 9 — multi-port web-svc
k patch svc web-svc -n services -p \
    '{"spec":{"ports":[{"name":"http","port":80,"targetPort":80},
                       {"name":"alt","port":8080,"targetPort":80}]}}' >/dev/null

# Task 10 — sessionAffinity ClientIP
k patch svc web-svc -n services \
    -p '{"spec":{"sessionAffinity":"ClientIP"}}' >/dev/null

info "lab 06 solved"
