#!/usr/bin/env bash
# Lab 24 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — DNS restored
check "coredns has ready replicas" \
    deploy_available kube-system coredns
check "kubernetes.default.svc resolves via cluster DNS" \
    probe_dns kubernetes.default.svc.cluster.local

# Task 2 — web-svc selector fixed
check_jsonpath "web-svc selects app=web" \
    svc/web-svc '{.spec.selector.app}' 'web' -n ts-net
check "web-svc has endpoints" \
    bash -c "kubectl --context $KUBE_CONTEXT -n ts-net get endpoints \
        web-svc -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null \
        | grep -q ."
check_eq "web-svc serves web-ok" \
    "$(probe_http http://web-svc.ts-net 2>/dev/null || true)" 'web-ok'

# Task 3 — api-svc targetPort fixed
check_jsonpath "api-svc targets port 8080" \
    svc/api-svc '{.spec.ports[0].targetPort}' '8080' -n ts-net
check_eq "api-svc serves api-ok" \
    "$(probe_http http://api-svc.ts-net 2>/dev/null || true)" 'api-ok'

# Task 4 — narrow allow added, deny-all kept, behavior proven
check_resource "db-deny-all still in place" \
    networkpolicy db-deny-all -n ts-net
check_resource "allow-client-to-db exists" \
    networkpolicy allow-client-to-db -n ts-net
_dbip="$(k get pod db -n ts-net -o jsonpath='{.status.podIP}' \
    2>/dev/null || true)"
check_eq "client pod can reach db" \
    "$(pod_http_get ts-net client "http://$_dbip" 2>/dev/null || true)" \
    'db-ok'
check_fails "unlabelled pod cannot reach db" \
    pod_http_get ts-net other "http://$_dbip"

# Task 5 — ingress backend fixed, hostname routed
check_jsonpath "web-ing backends to web-svc" \
    ingress/web-ing \
    '{.spec.rules[0].http.paths[0].backend.service.name}' \
    'web-svc' -n ts-net
check_eq "ingress serves web.ts.local" \
    "$(PROBE_ATTEMPTS=6 \
        probe_http http://ingress-nginx-controller.ingress-nginx \
        'Host: web.ts.local' 2>/dev/null || true)" 'web-ok'

# Task 6 — evidence files
check_file_contains "kube-proxy.txt lists the DaemonSet" \
    "$OUT_DIR/kube-proxy.txt" 'kube-proxy'
check "kube-proxy-log.txt is non-empty" \
    test -s "$OUT_DIR/kube-proxy-log.txt"
check_file_contains "endpointslices.txt covers web-svc" \
    "$OUT_DIR/endpointslices.txt" 'web-svc'

finish_checks
