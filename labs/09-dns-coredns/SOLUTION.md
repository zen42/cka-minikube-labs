# Lab 09 – Solution

### Task 1

```bash
kubectl exec client -n dns -- nslookup web > ~/cka-labs-out/09/nslookup-web.txt
```

Why the odd exit code: busybox `nslookup` can exit non-zero after a
search-domain NXDOMAIN even though the name resolved — always judge by the
printed answer.

### Task 2

```bash
echo "api.dns-other.svc.cluster.local" > ~/cka-labs-out/09/api-fqdn.txt
kubectl exec client -n dns -- wget -qO- -T 3 http://api.dns-other/
kubectl exec client -n dns -- nslookup api.dns-other.svc.cluster.local
```

Why: `api.dns-other` works because the search list expands it to
`api.dns-other.svc.cluster.local`; `api` alone would expand to
`api.dns.svc.cluster.local` first (wrong namespace).

### Task 3

```bash
kubectl exec client -n dns -- cat /etc/resolv.conf \
    > ~/cka-labs-out/09/resolv.conf
```

### Task 4

```bash
IP=$(kubectl get pod client -n dns -o jsonpath='{.status.podIP}')
echo "${IP//./-}.dns.pod.cluster.local" > ~/cka-labs-out/09/client-pod-dns.txt
kubectl exec client -n dns -- nslookup "$(cat ~/cka-labs-out/09/client-pod-dns.txt)"
```

### Task 5

```bash
DNSIP=$(kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}')
kubectl apply -n dns -f - <<EOF
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
```

### Task 6

```bash
kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}'
# edit it — add `    log` inside the `.:53 {` block if missing, and the
# line `10.1.2.3 legacy.internal` INSIDE the existing `hosts { ... }` block
# (minikube ships one for host.minikube.internal). Only add a new block
#     hosts {
#         10.1.2.3 legacy.internal
#         fallthrough
#     }
# if there is none: CoreDNS refuses to start with two hosts blocks in one
# server block ("plugin/hosts: this plugin can only be used once").
kubectl edit cm coredns -n kube-system   # or patch with the modified text
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns
kubectl exec client -n dns -- nslookup legacy.internal
```

If the rollout hangs, check `kubectl -n kube-system logs deploy/coredns` —
a Corefile syntax error crash-loops CoreDNS and breaks cluster DNS until you
fix the ConfigMap (teardown.sh restores the original).

Scripted variant (what solve.sh does):

```bash
CF=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')
HASLOG=$(printf '%s\n' "$CF" | grep -cE '^[[:space:]]*log([[:space:]]|$)' || true)
HASHOSTS=$(printf '%s\n' "$CF" | grep -cE '^[[:space:]]*hosts[[:space:]]*\{' || true)
NEW=$(printf '%s\n' "$CF" | awk -v haslog="$HASLOG" -v hashosts="$HASHOSTS" '
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
    {print}')
kubectl -n kube-system patch cm coredns --type=merge \
    -p "$(jq -n --arg cf "$NEW" '{data:{Corefile:$cf}}')"
kubectl -n kube-system rollout restart deployment coredns
```

Why: the existence checks run BEFORE the awk pass because the stock
`hosts` block sits after `prometheus`, where the awk would otherwise have
already inserted a second one.

### Task 7

```bash
# append to the Corefile:
#   example.internal:53 {
#       forward . 10.9.9.9
#   }
CF=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}')
NEW=$(printf '%s\nexample.internal:53 {\n    forward . 10.9.9.9\n}\n' "$CF")
kubectl -n kube-system patch cm coredns --type=merge \
    -p "$(jq -n --arg cf "$NEW" '{data:{Corefile:$cf}}')"
kubectl -n kube-system rollout restart deployment coredns
```

### Task 8

```bash
kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}' \
    > ~/cka-labs-out/09/kube-dns-ip.txt
```

### Task 9

```bash
kubectl exec client -n dns -- nslookup legacy.internal
kubectl -n kube-system logs deployment/coredns --tail=50 \
    > ~/cka-labs-out/09/coredns.log
```

Why: the `log` plugin from task 6 makes CoreDNS log every query — you will
see `legacy.internal` in the output.
