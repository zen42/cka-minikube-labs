# Lab 07 – Solution

### Task 1

```bash
kubectl apply -n netpol -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
```

### Task 2

```bash
kubectl apply -n netpol -f - <<'EOF'
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
```

Why: an ingress rule with no `from:` allows the port from everywhere —
including other namespaces.

### Task 3

```bash
kubectl apply -n netpol -f - <<'EOF'
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
```

### Task 4

```bash
kubectl apply -n netpol -f - <<'EOF'
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
```

### Task 5

```bash
kubectl apply -n netpol -f - <<'EOF'
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
```

Why: without an egress rule every pod can reach anything; once ANY egress
policy selects `db`, everything except the allowed DNS flows is dropped.

### Task 6

```bash
kubectl label namespace other team=platform
kubectl apply -n netpol -f - <<'EOF'
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
```

Why: putting `podSelector` and `namespaceSelector` in the SAME `from` item
would AND them ("frontend pods in platform ns"); as separate policies/list
items they are OR-ed.

### Task 7

```bash
kubectl get networkpolicy -n netpol > ~/cka-labs-out/07/netpols.txt
```
