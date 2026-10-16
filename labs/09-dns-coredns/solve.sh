#!/usr/bin/env bash
# Lab 09 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — nslookup web
# busybox nslookup can exit non-zero after a search-domain NXDOMAIN even when
# the name resolves — the captured output is what matters, hence || true.
k exec client -n dns -- nslookup web > "$OUT_DIR/nslookup-web.txt" || true

# Task 2 — api FQDN + both forms resolve
echo "api.dns-other.svc.cluster.local" > "$OUT_DIR/api-fqdn.txt"
# busybox nslookup skips the search list for names containing a dot —
# prove api.dns-other resolves through libc instead (wget returns 'api').
[[ "$(pod_http_get dns client http://api.dns-other/)" == "api" ]]
k exec client -n dns -- nslookup api.dns-other.svc.cluster.local >/dev/null

# Task 3 — client resolv.conf
k exec client -n dns -- cat /etc/resolv.conf > "$OUT_DIR/resolv.conf"

# Task 4 — pod DNS name + resolution
IP="$(k get pod client -n dns -o jsonpath='{.status.podIP}')"
echo "${IP//./-}.dns.pod.cluster.local" > "$OUT_DIR/client-pod-dns.txt"
k exec client -n dns -- nslookup "${IP//./-}.dns.pod.cluster.local" >/dev/null

# Task 5 — custom-dns pod
DNSIP="$(kube_dns_ip)"
k apply -n dns -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers: ["$DNSIP"]
    searches: [dns.svc.cluster.local, svc.cluster.local, cluster.local]
    options:
    - {name: ndots, value: "2"}
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
wait_pod_ready dns custom-dns 120s

# Task 6 — Corefile: log plugin + hosts entry, restart coredns.
# (minikube's stock Corefile already has `log` and a `hosts` block — merge,
# don't duplicate: add `log` only if absent, add our line inside the
# existing hosts block, else insert a new block before `prometheus`.)
CF="$(k -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')"
HASLOG=$(printf '%s\n' "$CF" | grep -cE '^[[:space:]]*log([[:space:]]|$)' || true)
HASHOSTS=$(printf '%s\n' "$CF" | grep -cE '^[[:space:]]*hosts[[:space:]]*\{' || true)
# decide up front: the stock hosts block may sit AFTER prometheus, so the
# awk must know whether one exists before it reaches the insertion point
# (CoreDNS refuses to start with two hosts blocks in one server block).
NEW="$(printf '%s\n' "$CF" | awk -v haslog="$HASLOG" -v hashosts="$HASHOSTS" '
    /^[[:space:]]*hosts[[:space:]]*\{/ && !hinserted {
        print; print "       10.1.2.3 legacy.internal"; hinserted=1; next}
    /^[[:space:]]*prometheus/ {
        if (!haslog) print "    log"
        if (!hashosts && !hinserted) {
            print "    hosts {"
            print "        10.1.2.3 legacy.internal"
            print "        fallthrough"
            print "    }"
            hinserted=1}}
    {print}')"
k -n kube-system patch cm coredns --type=merge \
    -p "$(jq -n --arg cf "$NEW" '{data:{Corefile:$cf}}')" >/dev/null
k -n kube-system rollout restart deployment coredns >/dev/null
wait_rollout kube-system coredns 180s
wait_for "coredns answers" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT exec client -n dns -- \
        nslookup kubernetes.default.svc.cluster.local 2>/dev/null \
        | grep -q Address"
wait_for "legacy.internal resolves" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT exec client -n dns -- \
        nslookup legacy.internal 2>/dev/null | grep -q '10\.1\.2\.3'"

# Task 7 — stub domain example.internal
CF="$(k -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')"
NEW="$(printf '%s\nexample.internal:53 {\n    forward . 10.9.9.9\n}\n' "$CF")"
k -n kube-system patch cm coredns --type=merge \
    -p "$(jq -n --arg cf "$NEW" '{data:{Corefile:$cf}}')" >/dev/null
k -n kube-system rollout restart deployment coredns >/dev/null
wait_rollout kube-system coredns 180s
wait_for "coredns answers" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT exec client -n dns -- \
        nslookup kubernetes.default.svc.cluster.local 2>/dev/null \
        | grep -q Address"

# Task 8 — kube-dns IP to file
kube_dns_ip > "$OUT_DIR/kube-dns-ip.txt"

# Task 9 — fresh lookup, then save coredns logs
k exec client -n dns -- nslookup legacy.internal >/dev/null || true
sleep 2
k -n kube-system logs deployment/coredns --tail=50 > "$OUT_DIR/coredns.log"

info "lab 09 solved"
