# Lab 11 – Solution

### Task 1

```bash
kubectl create serviceaccount app-sa -n sa
```

### Task 2

```bash
kubectl create rolebinding app-sa-lister -n sa \
    --role=pod-lister --serviceaccount=sa:app-sa
kubectl auth can-i list pods -n sa \
    --as=system:serviceaccount:sa:app-sa      # yes
kubectl auth can-i delete pods -n sa \
    --as=system:serviceaccount:sa:app-sa      # no
```

### Task 3

```bash
kubectl apply -n sa -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: api-client
spec:
  serviceAccountName: app-sa
  containers:
  - name: curl
    image: curlimages/curl:8.14.1
    command: ["sleep", "3600"]
EOF
```

### Task 4

```bash
kubectl exec api-client -n sa -- sh -c \
    'curl -sS --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
     -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
     https://kubernetes.default.svc/api/v1/namespaces/sa/pods' \
    > ~/cka-labs-out/11/pods-via-api.txt
```

Why: every pod gets a token + CA + namespace file mounted at
`/var/run/secrets/kubernetes.io/serviceaccount/` — that is the in-cluster
credential. `kubernetes.default.svc` is the apiserver's ClusterIP service.

### Task 5

```bash
kubectl apply -n sa -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-token
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

### Task 6

```bash
kubectl create token app-sa -n sa --duration=1h \
    > ~/cka-labs-out/11/token.txt
SERVER=$(kubectl config view --minify \
    -o jsonpath='{.clusters[0].cluster.server}')
CA_FILE=$(kubectl config view --minify --raw \
    -o jsonpath='{.clusters[0].cluster.certificate-authority}')
kubectl --kubeconfig=/dev/null --server="$SERVER" \
    --certificate-authority="$CA_FILE" \
    --token="$(cat ~/cka-labs-out/11/token.txt)" auth whoami \
    > ~/cka-labs-out/11/whoami.txt
```

Why: `kubectl create token` uses the TokenRequest API — short-lived,
audience-bound tokens; nothing is stored in the SA's `secrets` list
anymore. The empty `--kubeconfig=/dev/null` is needed because a context's
client certificate takes precedence over `--token` when both are present
— with the `cka-labs` context, `whoami` would report `minikube-user`
instead of the SA.

### Task 7

```bash
kubectl apply -n sa -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: projected-token
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: token
      mountPath: /var/run/secrets/tokens
  volumes:
  - name: token
    projected:
      sources:
      - serviceAccountToken:
          audience: vault
          expirationSeconds: 3600
          path: token
EOF
kubectl exec projected-token -n sa -- cat /var/run/secrets/tokens/token
```

### Task 8

```bash
kubectl create secret docker-registry regcred -n sa \
    --docker-server=registry.example.com \
    --docker-username=bob --docker-password=pass
kubectl patch serviceaccount app-sa -n sa \
    -p '{"imagePullSecrets":[{"name":"regcred"}]}'
```

### Task 9

```bash
kubectl create clusterrolebinding app-sa-view \
    --clusterrole=view --serviceaccount=sa:app-sa
```

### Task 10

```bash
kubectl get sa,rolebinding -n sa -o wide \
    > ~/cka-labs-out/11/sa-report.txt
```
