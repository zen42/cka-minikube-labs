#!/usr/bin/env bash
# Lab 07 verify — policy objects + enforced connectivity matrix.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — default deny ingress exists
check_jsonpath "default-deny-ingress selects all pods" \
    networkpolicy/default-deny-ingress '{.spec.podSelector}' '{}' -n netpol
check_jsonpath "default-deny-ingress type Ingress" \
    networkpolicy/default-deny-ingress '{.spec.policyTypes[0]}' 'Ingress' \
    -n netpol

# Task 2 — allow ingress to frontend:80 from anywhere
check_resource "allow-frontend-ingress exists" \
    networkpolicy allow-frontend-ingress -n netpol

# Task 3 — allow-frontend-to-backend exists
check_resource "allow-frontend-to-backend exists" \
    networkpolicy allow-frontend-to-backend -n netpol

# Task 4 — allow-backend-to-db exists
check_resource "allow-backend-to-db exists" \
    networkpolicy allow-backend-to-db -n netpol

# Task 5 — db-egress-dns-only exists
check_resource "db-egress-dns-only exists" \
    networkpolicy db-egress-dns-only -n netpol
check_jsonpath "db egress policy type is Egress" \
    networkpolicy/db-egress-dns-only '{.spec.policyTypes[0]}' 'Egress' \
    -n netpol

# Task 6 — other ns labeled + platform policy exists
check_jsonpath "namespace other labeled team=platform" \
    namespace/other '{.metadata.labels.team}' 'platform'
check_resource "allow-platform-ns-to-backend exists" \
    networkpolicy allow-platform-ns-to-backend -n netpol

# Task 7 — netpols.txt saved
check_file_contains "netpols.txt lists policies" \
    "$OUT_DIR/netpols.txt" 'default-deny-ingress|allow-frontend-ingress'

# --- connectivity matrix (final state) --------------------------------------
check_eq "outsider can reach frontend" \
    "$(pod_http_get other outsider \
        http://frontend.netpol.svc.cluster.local 2>/dev/null)" "frontend"
check_eq "outsider can reach backend (platform ns)" \
    "$(pod_http_get other outsider \
        http://backend.netpol.svc.cluster.local 2>/dev/null)" "backend"
check_eq "frontend can reach backend" \
    "$(pod_http_get netpol frontend \
        http://backend.netpol.svc.cluster.local 2>/dev/null)" "backend"
check_fails "frontend CANNOT reach db" \
    pod_http_get netpol frontend http://db.netpol.svc.cluster.local
check_eq "backend can reach db" \
    "$(pod_http_get netpol backend \
        http://db.netpol.svc.cluster.local 2>/dev/null)" "db"
check_fails "db CANNOT reach frontend (egress denied)" \
    pod_http_get netpol db http://frontend.netpol.svc.cluster.local
check "db can still resolve DNS" \
    k exec db -n netpol -- nslookup backend.netpol.svc.cluster.local
check_fails "outsider CANNOT reach db" \
    pod_http_get other outsider http://db.netpol.svc.cluster.local

finish_checks
