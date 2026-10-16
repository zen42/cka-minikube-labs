#!/usr/bin/env bash
# Lab 08 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — apps-ingress: host + two path rules
k apply -n ingress -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: apps.example.com
    http:
      paths:
      - path: /shop
        pathType: Prefix
        backend: {service: {name: shop, port: {number: 80}}}
      - path: /blog
        pathType: Prefix
        backend: {service: {name: blog, port: {number: 80}}}
EOF

# Task 2 — TLS secret + spec.tls
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$OUT_DIR/apps.key" -out "$OUT_DIR/apps.crt" -days 1 \
    -subj '/CN=apps.example.com' \
    -addext 'subjectAltName=DNS:apps.example.com' >/dev/null 2>&1
k create secret tls apps-tls -n ingress \
    --cert="$OUT_DIR/apps.crt" --key="$OUT_DIR/apps.key" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
rm -f "$OUT_DIR/apps.key" "$OUT_DIR/apps.crt"
k patch ingress apps-ingress -n ingress --type=merge -p \
    '{"spec":{"tls":[{"hosts":["apps.example.com"],"secretName":"apps-tls"}]}}' \
    >/dev/null

# Task 3 — blog-ingress
k apply -n ingress -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blog-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: blog.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend: {service: {name: blog, port: {number: 80}}}
EOF

# Task 4 — save ingressclass + describe
wait_for "apps-ingress programmed (address set)" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ingress get ingress \
        apps-ingress -o jsonpath='{.status.loadBalancer.ingress}' 2>/dev/null \
        | grep -q ."
k get ingressclass > "$OUT_DIR/ingressclasses.txt"
k describe ingress apps-ingress -n ingress > "$OUT_DIR/apps-ingress.txt"

# Task 5 — Gateway
k apply -n ingress -f - >/dev/null <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: apps-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
EOF
wait_for "Gateway apps-gateway Programmed" 240 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ingress get gateway \
        apps-gateway \
        -o jsonpath='{.status.conditions[?(@.type==\"Programmed\")].status}' \
        2>/dev/null | grep -q True"
wait_for "data-plane svc apps-gateway-nginx has endpoints" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n ingress get endpoints \
        apps-gateway-nginx --no-headers 2>/dev/null | grep -q '[0-9]'"

# Task 6 — HTTPRoute shop-route
k apply -n ingress -f - >/dev/null <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-route
spec:
  parentRefs: [{name: apps-gateway}]
  hostnames: [shop.gw.example.com]
  rules:
  - backendRefs: [{name: shop, port: 80}]
EOF

# Task 7 — HTTPRoute apps-route
k apply -n ingress -f - >/dev/null <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: apps-route
spec:
  parentRefs: [{name: apps-gateway}]
  hostnames: [apps.gw.example.com]
  rules:
  - matches: [{path: {type: PathPrefix, value: /shop}}]
    backendRefs: [{name: shop, port: 80}]
  - matches: [{path: {type: PathPrefix, value: /blog}}]
    backendRefs: [{name: blog, port: 80}]
EOF

# Task 8 — HTTPRoute canary-route (header match beats default)
k apply -n ingress -f - >/dev/null <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-route
spec:
  parentRefs: [{name: apps-gateway}]
  hostnames: [canary.gw.example.com]
  rules:
  - matches:
    - headers:
      - {name: x-version, value: v2}
    backendRefs: [{name: blog, port: 80}]
  - backendRefs: [{name: shop, port: 80}]
EOF

# Task 9 — save gateway state
k get gateway,httproute -n ingress > "$OUT_DIR/gateway.txt"

info "lab 08 solved"
