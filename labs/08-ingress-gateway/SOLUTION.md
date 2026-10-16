# Lab 08 – Solution

### Task 1

```bash
kubectl apply -n ingress -f - <<'EOF'
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
```

### Task 2

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /tmp/apps.key -out /tmp/apps.crt -days 1 \
    -subj '/CN=apps.example.com' \
    -addext 'subjectAltName=DNS:apps.example.com'
kubectl create secret tls apps-tls -n ingress \
    --cert=/tmp/apps.crt --key=/tmp/apps.key
kubectl patch ingress apps-ingress -n ingress --type=merge -p \
    '{"spec":{"tls":[{"hosts":["apps.example.com"],"secretName":"apps-tls"}]}}'
```

Why the SAN: without `subjectAltName` the controller logs "certificate
relies on legacy Common Name" warnings. Once TLS is configured, HTTP
requests to `apps.example.com` get a `308` redirect to
`https://apps.example.com` — so probes must use `https://` on the
controller service (the redirect target hostname does not resolve
in-cluster).

### Task 3

```bash
kubectl apply -n ingress -f - <<'EOF'
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
```

### Task 4

```bash
kubectl get ingressclass > ~/cka-labs-out/08/ingressclasses.txt
kubectl describe ingress apps-ingress -n ingress \
    > ~/cka-labs-out/08/apps-ingress.txt
```

### Task 5

```bash
kubectl apply -n ingress -f - <<'EOF'
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
kubectl wait --for='jsonpath={.status.conditions[?(@.type=="Programmed")].status}=True' \
    gateway/apps-gateway -n ingress --timeout=120s
kubectl get svc -n ingress   # the data plane: apps-gateway-nginx
```

Why: NGF does not share one big data plane — each Gateway gets its own
Deployment+Service named `<gateway>-nginx` in the Gateway's namespace.

### Task 6

```bash
kubectl apply -n ingress -f - <<'EOF'
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
```

### Task 7

```bash
kubectl apply -n ingress -f - <<'EOF'
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
```

### Task 8

```bash
kubectl apply -n ingress -f - <<'EOF'
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
```

Why: rules are evaluated in order — the header-matching rule must come
before the catch-all default rule.

### Task 9

```bash
kubectl get gateway,httproute -n ingress > ~/cka-labs-out/08/gateway.txt
```
