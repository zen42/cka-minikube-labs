#!/usr/bin/env bash
# Lab 11 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — serviceaccount
k create serviceaccount app-sa -n sa 2>/dev/null \
    || k get serviceaccount app-sa -n sa >/dev/null

# Task 2 — bind pod-lister to app-sa
k create rolebinding app-sa-lister -n sa \
    --role=pod-lister --serviceaccount=sa:app-sa 2>/dev/null \
    || k get rolebinding app-sa-lister -n sa >/dev/null
SA="system:serviceaccount:sa:app-sa"
[[ "$(k auth can-i list pods -n sa --as="$SA")" == "yes" ]]
[[ "$(k auth can-i delete pods -n sa --as="$SA")" == "no" ]]

# Task 3 — api-client pod
k apply -n sa -f - >/dev/null <<'EOF'
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
wait_pod_ready sa api-client 180s

# Task 4 — call the API from inside the pod with the mounted token
k exec api-client -n sa -- sh -c \
    'curl -sS --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
     -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
     https://kubernetes.default.svc/api/v1/namespaces/sa/pods' \
    > "$OUT_DIR/pods-via-api.txt"

# Task 5 — no-token pod
k apply -n sa -f - >/dev/null <<'EOF'
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
wait_pod_ready sa no-token 120s

# Task 6 — TokenRequest token + whoami
k create token app-sa -n sa --duration=1h > "$OUT_DIR/token.txt"
# the context's client cert takes precedence over --token, so force
# token-only auth with an empty kubeconfig + explicit server/CA.
SERVER="$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
CA_FILE="$(k config view --minify --raw \
    -o jsonpath='{.clusters[0].cluster.certificate-authority}')"
if [[ -z "$CA_FILE" ]]; then
    CA_FILE="$OUT_DIR/ca.crt"
    k config view --minify --raw \
        -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
        | base64 -d > "$CA_FILE"
fi
kubectl --kubeconfig=/dev/null --server="$SERVER" \
    --certificate-authority="$CA_FILE" \
    --token="$(cat "$OUT_DIR/token.txt")" auth whoami \
    > "$OUT_DIR/whoami.txt"

# Task 7 — projected-token pod
k apply -n sa -f - >/dev/null <<'EOF'
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
wait_pod_ready sa projected-token 120s

# Task 8 — regcred secret + imagePullSecrets on app-sa
k create secret docker-registry regcred -n sa \
    --docker-server=registry.example.com \
    --docker-username=bob --docker-password=pass \
    --dry-run=client -o yaml | k apply -f - >/dev/null
k patch serviceaccount app-sa -n sa \
    -p '{"imagePullSecrets":[{"name":"regcred"}]}' >/dev/null

# Task 9 — cluster-wide view for app-sa
k create clusterrolebinding app-sa-view \
    --clusterrole=view --serviceaccount=sa:app-sa 2>/dev/null \
    || k get clusterrolebinding app-sa-view >/dev/null
[[ "$(k auth can-i list deployments -n kube-system --as="$SA")" == "yes" ]]
[[ "$(k auth can-i create deployments -n kube-system --as="$SA")" == "no" ]]

# Task 10 — report file
k get sa,rolebinding -n sa -o wide > "$OUT_DIR/sa-report.txt"

info "lab 11 solved"
