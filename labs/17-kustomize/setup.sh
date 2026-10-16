#!/usr/bin/env bash
# Lab 17 setup — clean ns kz-dev/kz-prod and write the shared base into
# $OUT_DIR/base (the overlays are the learner's job).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# reset to a clean start state: delete anything a previous run applied
k delete -k "$OUT_DIR/overlays/dev" >/dev/null 2>&1 || true
k delete -k "$OUT_DIR/overlays/prod" >/dev/null 2>&1 || true
delete_namespace_if_exists kz-dev
delete_namespace_if_exists kz-prod

ensure_namespace kz-dev
ensure_namespace kz-prod

rm -rf "$OUT_DIR/base" "$OUT_DIR/overlays"
mkdir -p "$OUT_DIR/base"

cat > "$OUT_DIR/base/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF

cat > "$OUT_DIR/base/service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector: {app: web}
  ports:
  - port: 80
    targetPort: 80
EOF

cat > "$OUT_DIR/base/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

info "lab 17 setup done — base written to $OUT_DIR/base"
