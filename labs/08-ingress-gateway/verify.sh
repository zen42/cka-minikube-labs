#!/usr/bin/env bash
# Lab 08 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

ING_HTTP="http://ingress-nginx-controller.ingress-nginx.svc.cluster.local"
# apps.example.com has TLS configured (task 2), so plain HTTP gets a 308
# redirect to https://apps.example.com — which does not resolve inside the
# cluster. Probe HTTPS instead (busybox wget does not verify the cert).
ING_HTTPS="https://ingress-nginx-controller.ingress-nginx.svc.cluster.local"
GW="http://apps-gateway-nginx.ingress.svc.cluster.local"

# Task 1 — apps-ingress spec + routing
check_jsonpath "apps-ingress class is nginx" \
    ingress/apps-ingress '{.spec.ingressClassName}' 'nginx' -n ingress
check_jsonpath "apps-ingress host is apps.example.com" \
    ingress/apps-ingress '{.spec.rules[0].host}' 'apps.example.com' -n ingress
check_eq "/shop routes to shop" \
    "$(PROBE_ATTEMPTS=6 \
        probe_http "$ING_HTTPS/shop" 'Host: apps.example.com')" "shop"
check_eq "/blog routes to blog" \
    "$(PROBE_ATTEMPTS=6 \
        probe_http "$ING_HTTPS/blog" 'Host: apps.example.com')" "blog"

# Task 2 — TLS on the ingress
check_jsonpath "apps-ingress tls secretName is apps-tls" \
    ingress/apps-ingress '{.spec.tls[0].secretName}' 'apps-tls' -n ingress
check_jsonpath "apps-ingress tls host is apps.example.com" \
    ingress/apps-ingress '{.spec.tls[0].hosts[0]}' 'apps.example.com' -n ingress

# Task 3 — blog-ingress answers on its host (no TLS here — plain HTTP)
check_eq "blog.example.com returns blog" \
    "$(probe_http "$ING_HTTP/" 'Host: blog.example.com')" "blog"

# Task 4 — files saved
check_file_contains "ingressclasses.txt lists nginx" \
    "$OUT_DIR/ingressclasses.txt" 'nginx'
check_file_contains "apps-ingress.txt describe saved" \
    "$OUT_DIR/apps-ingress.txt" 'apps.example.com'

# Task 5 — Gateway programmed
check_jsonpath "apps-gateway gatewayClassName is nginx" \
    gateway/apps-gateway '{.spec.gatewayClassName}' 'nginx' -n ingress
check_jsonpath "apps-gateway is Programmed" \
    gateway/apps-gateway \
    '{.status.conditions[?(@.type=="Programmed")].status}' 'True' -n ingress
check_resource "data-plane service apps-gateway-nginx exists" \
    svc apps-gateway-nginx -n ingress

# Task 6 — shop-route accepted + answers
check "shop-route is Accepted" \
    bash -c "kubectl --context $KUBE_CONTEXT -n ingress get httproute \
        shop-route \
        -o jsonpath='{.status.parents[*].conditions[?(@.type==\"Accepted\")].status}' \
        | grep -q True"
check_eq "shop.gw.example.com returns shop" \
    "$(PROBE_ATTEMPTS=6 probe_http "$GW/" 'Host: shop.gw.example.com')" "shop"

# Task 7 — apps-route path rules
check_eq "apps.gw.example.com/shop returns shop" \
    "$(PROBE_ATTEMPTS=6 probe_http "$GW/shop" 'Host: apps.gw.example.com')" "shop"
check_eq "apps.gw.example.com/blog returns blog" \
    "$(PROBE_ATTEMPTS=6 probe_http "$GW/blog" 'Host: apps.gw.example.com')" "blog"

# Task 8 — canary header routing
check_eq "canary with x-version: v2 returns blog" \
    "$(PROBE_ATTEMPTS=6 probe_http "$GW/" 'Host: canary.gw.example.com' 'x-version: v2')" "blog"
check_eq "canary without header returns shop" \
    "$(PROBE_ATTEMPTS=6 probe_http "$GW/" 'Host: canary.gw.example.com')" "shop"

# Task 9 — gateway.txt saved
check_file_contains "gateway.txt lists apps-gateway" \
    "$OUT_DIR/gateway.txt" 'apps-gateway'
check_file_contains "gateway.txt lists httproutes" \
    "$OUT_DIR/gateway.txt" 'shop-route|apps-route|canary-route'

finish_checks
