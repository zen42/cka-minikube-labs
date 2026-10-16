#!/usr/bin/env bash
# Lab 07 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — default deny ingress
k apply -n netpol -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF

# Task 2 — allow ingress to frontend:80 from anywhere
k apply -n netpol -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
spec:
  podSelector: {matchLabels: {app: frontend}}
  policyTypes: [Ingress]
  ingress:
  - ports: [{protocol: TCP, port: 80}]
EOF

# Task 3 — backend:80 only from app=frontend
k apply -n netpol -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector: {matchLabels: {app: backend}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: frontend}}
    ports: [{protocol: TCP, port: 80}]
EOF

# Task 4 — db:80 only from app=backend
k apply -n netpol -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: backend}}
    ports: [{protocol: TCP, port: 80}]
EOF

# Task 5 — db egress: DNS only
k apply -n netpol -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-egress-dns-only
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - {protocol: UDP, port: 53}
    - {protocol: TCP, port: 53}
EOF

# Task 6 — other ns labeled team=platform; allow its pods to backend
k label namespace other team=platform --overwrite >/dev/null
k apply -n netpol -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-platform-ns-to-backend
spec:
  podSelector: {matchLabels: {app: backend}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector: {matchLabels: {team: platform}}
    ports: [{protocol: TCP, port: 80}]
EOF

# Task 7 — save policy list
k get networkpolicy -n netpol > "$OUT_DIR/netpols.txt"

info "lab 07 solved"
