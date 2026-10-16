#!/usr/bin/env bash
# Lab 03 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — create the missing ConfigMap; reader unblocks
k create configmap app-config -n config \
    --from-literal=APP_MODE=production --from-literal=LOG_LEVEL=info \
    --dry-run=client -o yaml | k apply -f - >/dev/null
wait_rollout config reader 120s

# Task 2 — ConfigMap from file
k create configmap app-props -n config \
    --from-file="$LAB_DIR/manifests/app.properties" \
    --dry-run=client -o yaml | k apply -f - >/dev/null

# Task 3 — generic secret
k create secret generic db-creds -n config \
    --from-literal=username=admin --from-literal='password=S3cr3t!' \
    --dry-run=client -o yaml | k apply -f - >/dev/null

# Task 4 — TLS secret from a self-signed cert
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$OUT_DIR/web.key" -out "$OUT_DIR/web.crt" -days 1 \
    -subj '/CN=web.example.com' >/dev/null 2>&1
k create secret tls web-tls -n config \
    --cert="$OUT_DIR/web.crt" --key="$OUT_DIR/web.key" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
rm -f "$OUT_DIR/web.key" "$OUT_DIR/web.crt"

# Task 5 — docker-registry secret
k create secret docker-registry regcred -n config \
    --docker-server=registry.example.com --docker-username=bob \
    --docker-password=pass --docker-email=bob@example.com \
    --dry-run=client -o yaml | k apply -f - >/dev/null

# Task 6 — env from configMapKeyRef + secretKeyRef
k apply -n config -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    env:
    - name: MODE
      valueFrom:
        configMapKeyRef: {name: app-config, key: APP_MODE}
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef: {name: db-creds, key: password}
EOF
wait_pod_ready config env-pod 120s

# Task 7 — volumes: CM + secret, read-only
k apply -n config -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: vol-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: props, mountPath: /etc/props, readOnly: true}
    - {name: creds, mountPath: /etc/creds, readOnly: true}
  volumes:
  - name: props
    configMap: {name: app-props}
  - name: creds
    secret: {secretName: db-creds}
EOF
wait_pod_ready config vol-pod 120s

# Task 8 — update CM, rollout restart
k patch configmap app-config -n config \
    --type=merge -p '{"data":{"LOG_LEVEL":"debug"}}' >/dev/null
k rollout restart deployment reader -n config >/dev/null
wait_rollout config reader 120s

# Task 9 — immutable ConfigMap
k apply -n config -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: static-config
immutable: true
data:
  version: "1"
EOF

# Task 10 — decode secret to file
k get secret db-creds -n config \
    -o jsonpath='{.data.password}' | base64 -d > "$OUT_DIR/password.txt"

info "lab 03 solved"
