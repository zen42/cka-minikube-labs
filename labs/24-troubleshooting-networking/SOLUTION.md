# Lab 24 – Solution

`$OUT` is `~/cka-labs-out/24`. The flow per task: `get pod` →
`get svc` → `get endpoints` → `describe` → fix → probe.

### Task 1

```bash
kubectl run dnsprobe --rm -i --restart=Never --image=busybox:1.36 \
    -- nslookup kubernetes.default.svc.cluster.local   # fails
kubectl -n kube-system get deploy coredns   # 0/1 ready — scaled to 0!
kubectl -n kube-system scale deployment coredns --replicas=1
kubectl -n kube-system rollout status deploy/coredns --timeout=240s
```

### Task 2

```bash
kubectl get endpoints web-svc -n ts-net     # <none>
kubectl get svc web-svc -n ts-net -o yaml | grep -A2 selector
# app: webb — but the pod is labelled app=web
kubectl patch service web-svc -n ts-net --type=json -p \
    '[{"op":"replace","path":"/spec/selector/app","value":"web"}]'
kubectl get endpoints web-svc -n ts-net     # pod IP appears
kubectl run probe --rm -i --restart=Never --image=busybox:1.36 \
    -- wget -qO- http://web-svc.ts-net      # web-ok
```

### Task 3

```bash
kubectl get endpoints api-svc -n ts-net     # has endpoints — svc finds the pod
kubectl describe svc api-svc -n ts-net      # port 80 -> targetPort 80
kubectl describe pod api -n ts-net          # ...but the container listens 8080
kubectl patch service api-svc -n ts-net --type=json -p \
    '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
# http://api-svc.ts-net -> api-ok
```

### Task 4

```bash
kubectl get networkpolicy -n ts-net         # db-deny-all: ingress, no rules
kubectl apply -n ts-net -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-client-to-db}
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: client}}
    ports: [{port: 80}]
EOF
dbip=$(kubectl get pod db -n ts-net -o jsonpath='{.status.podIP}')
kubectl exec client -n ts-net -- wget -qO- "http://$dbip"   # db-ok
kubectl exec other  -n ts-net -- wget -qO- -T 3 "http://$dbip"  # times out
```

### Task 5

```bash
kubectl describe ingress web-ing -n ts-net  # backend service "web-service" DNE
kubectl patch ingress web-ing -n ts-net --type=json -p \
    '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"web-svc"}]'
kubectl run probe --rm -i --restart=Never --image=busybox:1.36 \
    -- wget -qO- --header 'Host: web.ts.local' \
    http://ingress-nginx-controller.ingress-nginx   # web-ok
```

### Task 6

```bash
kubectl -n kube-system get ds kube-proxy > $OUT/kube-proxy.txt
kubectl -n kube-system logs ds/kube-proxy --tail=20 \
    > $OUT/kube-proxy-log.txt
kubectl get endpointslices -n ts-net > $OUT/endpointslices.txt
```
