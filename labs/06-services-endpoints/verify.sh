#!/usr/bin/env bash
# Lab 06 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

node_ip() {
    k get nodes \
        -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'
}

# Task 1 — web-svc ClusterIP, 3 endpoints, answers "web"
check_jsonpath "web-svc is ClusterIP" svc/web-svc '{.spec.type}' 'ClusterIP' \
    -n services
check "web-svc has 3 ready endpoints" \
    bash -c "test \$(kubectl --context $KUBE_CONTEXT -n services \
        get endpointslices -l kubernetes.io/service-name=web-svc -o json \
        | jq '[.items[].endpoints[] | select(.conditions.ready != false)] | length') -ge 3"
check_eq "web-svc returns token web" \
    "$(probe_http http://web-svc.services.svc.cluster.local)" "web"

# Task 2 — NodePort 30080 answers via node IP
check_jsonpath "web-nodeport nodePort is 30080" \
    svc/web-nodeport '{.spec.ports[0].nodePort}' '30080' -n services
check_eq "nodePort 30080 returns token web" \
    "$(probe_http "http://$(node_ip):30080")" "web"

# Task 3 — LoadBalancer service (EXTERNAL-IP stays pending on minikube)
check_jsonpath "web-lb type is LoadBalancer" \
    svc/web-lb '{.spec.type}' 'LoadBalancer' -n services

# Task 4 — legacy-svc selector fixed, endpoints present
check_jsonpath "legacy-svc selector is app=legacy-api" \
    svc/legacy-svc '{.spec.selector.app}' 'legacy-api' -n services
check "legacy-svc has >=2 endpoints" \
    bash -c "test \$(kubectl --context $KUBE_CONTEXT -n services \
        get endpointslices -l kubernetes.io/service-name=legacy-svc -o json \
        | jq '[.items[].endpoints[] | select(.conditions.ready != false)] | length') -ge 2"

# Task 5 — headless service returns pod IPs
check_jsonpath "web-headless clusterIP is None" \
    svc/web-headless '{.spec.clusterIP}' 'None' -n services
_hout="$(probe_dns web-headless.services.svc.cluster.local 2>/dev/null || true)"
_hn=0
for _ip in $(k -n services get pods -l app=web \
        -o jsonpath='{.items[*].status.podIP}' 2>/dev/null); do
    grep -qF "$_ip" <<<"$_hout" && _hn=$((_hn+1))
done
check "web-headless DNS returns >=2 real pod IPs" test "$_hn" -ge 2

# Task 6 — ExternalName
check_jsonpath "external-db type is ExternalName" \
    svc/external-db '{.spec.type}' 'ExternalName' -n services
check_jsonpath "external-db points to db.example.com" \
    svc/external-db '{.spec.externalName}' 'db.example.com' -n services

# Task 7 — manual-svc + hand-written EndpointSlice
check "EndpointSlice labeled for manual-svc exists" \
    bash -c "kubectl --context $KUBE_CONTEXT -n services get endpointslices \
        -l kubernetes.io/service-name=manual-svc --no-headers 2>/dev/null \
        | grep -q ."
check "manual-svc slice address is a web pod IP" \
    bash -c "ip=\$(kubectl --context $KUBE_CONTEXT -n services \
        get endpointslices -l kubernetes.io/service-name=manual-svc \
        -o jsonpath='{.items[0].endpoints[0].addresses[0]}'); \
        kubectl --context $KUBE_CONTEXT -n services get pods -l app=web \
        -o jsonpath='{.items[*].status.podIP}' | grep -qw \"\$ip\""
check_eq "manual-svc:8080 returns token web" \
    "$(probe_http http://manual-svc.services.svc.cluster.local:8080)" "web"

# Task 8 — web-endpoints.txt saved
check_file_contains "web-endpoints.txt lists web-svc slice" \
    "$OUT_DIR/web-endpoints.txt" 'web-svc'

# Task 9 — multi-port web-svc
check_jsonpath "web-svc port 80 named http" \
    svc/web-svc '{.spec.ports[?(@.port==80)].name}' 'http' -n services
check_jsonpath "web-svc port 8080 named alt" \
    svc/web-svc '{.spec.ports[?(@.port==8080)].name}' 'alt' -n services
check_eq "web-svc:8080 returns token web" \
    "$(probe_http http://web-svc.services.svc.cluster.local:8080)" "web"

# Task 10 — sessionAffinity ClientIP
check_jsonpath "web-svc sessionAffinity is ClientIP" \
    svc/web-svc '{.spec.sessionAffinity}' 'ClientIP' -n services

finish_checks
