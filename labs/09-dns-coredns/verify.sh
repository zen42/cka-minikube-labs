#!/usr/bin/env bash
# Lab 09 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

WEB_IP="$(k -n dns get svc web -o jsonpath='{.spec.clusterIP}' \
    2>/dev/null || echo NOMATCH)"
API_IP="$(k -n dns-other get svc api -o jsonpath='{.spec.clusterIP}' \
    2>/dev/null || echo NOMATCH)"
DNS_IP="$(kube_dns_ip 2>/dev/null || echo NOMATCH)"
CLIENT_IP="$(k get pod client -n dns -o jsonpath='{.status.podIP}' \
    2>/dev/null || echo NOMATCH)"

# client_lookup_matches <name> <fixed-string> — nslookup from the `client`
# pod, retried (CoreDNS restarts leave a gap where lookups fail outright).
client_lookup_matches() {
    local name="$1" want="$2" i
    for i in 1 2 3; do
        if k exec client -n dns -- nslookup "$name" 2>/dev/null \
                | grep -qF "$want"; then
            return 0
        fi
        sleep 3
    done
    return 1
}

# Task 1 — nslookup-web.txt holds web's ClusterIP
check_file_contains "nslookup-web.txt has web's ClusterIP" \
    "$OUT_DIR/nslookup-web.txt" "Address.*${WEB_IP//./\\.}"

# Task 2 — api-fqdn.txt correct + both forms resolve
check_eq "api-fqdn.txt is the FQDN" \
    "$(cat "$OUT_DIR/api-fqdn.txt" 2>/dev/null | tr -d '[:space:]' || true)" \
    "api.dns-other.svc.cluster.local"
# busybox nslookup treats any name CONTAINING a dot as fully-qualified and
# skips the resolv.conf search list (api.dns-other → NXDOMAIN) — the libc
# resolver inside wget honors it, so the short form is proven via HTTP.
check_eq "client resolves api.dns-other (search list)" \
    "$(pod_http_get dns client http://api.dns-other/ 2>/dev/null)" "api"
check "client resolves the api FQDN" \
    client_lookup_matches api.dns-other.svc.cluster.local "$API_IP"

# Task 3 — resolv.conf saved
check_file_contains "resolv.conf searches dns.svc.cluster.local" \
    "$OUT_DIR/resolv.conf" 'dns\.svc\.cluster\.local'
check "resolv.conf nameserver is kube-dns" \
    grep -Fq "nameserver $DNS_IP" "$OUT_DIR/resolv.conf"

# Task 4 — pod DNS name saved + resolves
check_eq "client-pod-dns.txt is the pod DNS name" \
    "$(cat "$OUT_DIR/client-pod-dns.txt" 2>/dev/null | tr -d '[:space:]' || true)" \
    "${CLIENT_IP//./-}.dns.pod.cluster.local"
_pdout="$(probe_dns "${CLIENT_IP//./-}.dns.pod.cluster.local" \
    2>/dev/null || true)"
grep -qF "$CLIENT_IP" <<<"$_pdout" && _pdok=0 || _pdok=1
check "pod DNS name resolves to the pod IP" test "$_pdok" -eq 0

# Task 5 — custom-dns pod dnsConfig
check_jsonpath "custom-dns dnsPolicy is None" \
    pod/custom-dns '{.spec.dnsPolicy}' 'None' -n dns
check_jsonpath "custom-dns nameserver is kube-dns IP" \
    pod/custom-dns '{.spec.dnsConfig.nameservers[0]}' "$DNS_IP" -n dns
check_jsonpath "custom-dns has dns.svc.cluster.local search" \
    pod/custom-dns '{.spec.dnsConfig.searches[0]}' \
    'dns.svc.cluster.local' -n dns
check_jsonpath "custom-dns ndots is 2" \
    pod/custom-dns '{.spec.dnsConfig.options[?(@.name=="ndots")].value}' '2' \
    -n dns

# Task 6 — Corefile has log + hosts, legacy.internal resolves
check "Corefile enables the log plugin" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get cm coredns \
        -o jsonpath='{.data.Corefile}' | grep -qE '^\s+log(\s|$)'"
check "Corefile maps legacy.internal" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get cm coredns \
        -o jsonpath='{.data.Corefile}' | grep -q '10\.1\.2\.3.*legacy\.internal'"
check "client resolves legacy.internal to 10.1.2.3" \
    client_lookup_matches legacy.internal '10.1.2.3'

# Task 7 — stub domain in Corefile
check "Corefile has example.internal stub" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get cm coredns \
        -o jsonpath='{.data.Corefile}' | grep -q 'example\.internal:53'"
check "stub forwards to 10.9.9.9" \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get cm coredns \
        -o jsonpath='{.data.Corefile}' | grep -q '10\.9\.9\.9'"

# Task 8 — kube-dns-ip.txt
check_eq "kube-dns-ip.txt has the ClusterIP" \
    "$(cat "$OUT_DIR/kube-dns-ip.txt" 2>/dev/null | tr -d '[:space:]' || true)" \
    "$DNS_IP"

# Task 9 — coredns.log captured the lookup
check_file_contains "coredns.log shows the legacy.internal query" \
    "$OUT_DIR/coredns.log" 'legacy\.internal'

finish_checks
