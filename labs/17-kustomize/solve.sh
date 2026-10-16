#!/usr/bin/env bash
# Lab 17 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — render the plain base
k kustomize "$OUT_DIR/base" > "$OUT_DIR/base-rendered.yaml"

# Task 2 — dev overlay: ns kz-dev, dev- prefix, env=dev labels,
# 1 replica, generated app-config consumed via envFrom
mkdir -p "$OUT_DIR/overlays/dev"
cat > "$OUT_DIR/overlays/dev/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kz-dev
namePrefix: dev-
labels:
- pairs:
    env: dev
  includeSelectors: true
resources:
- ../../base
replicas:
- name: web
  count: 1
configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=debug
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web
    spec:
      template:
        spec:
          containers:
          - name: app
            envFrom:
            - configMapRef:
                name: app-config
EOF

# Task 3 — prod overlay: ns kz-prod, prod- prefix, env=prod labels,
# 3 replicas, nginx:1.27, JSON6902 cpu request patch
mkdir -p "$OUT_DIR/overlays/prod"
cat > "$OUT_DIR/overlays/prod/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kz-prod
namePrefix: prod-
labels:
- pairs:
    env: prod
  includeSelectors: true
resources:
- ../../base
replicas:
- name: web
  count: 3
images:
- name: nginx
  newTag: "1.27"
configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=info
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web
    spec:
      template:
        spec:
          containers:
          - name: app
            envFrom:
            - configMapRef:
                name: app-config
- target:
    kind: Deployment
    name: web
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 100m
EOF

# Task 4 — build both overlays to files
kustomize build "$OUT_DIR/overlays/dev" > "$OUT_DIR/dev-rendered.yaml"
kustomize build "$OUT_DIR/overlays/prod" > "$OUT_DIR/prod-rendered.yaml"

# Task 5 — apply both
k apply -k "$OUT_DIR/overlays/dev" >/dev/null
k apply -k "$OUT_DIR/overlays/prod" >/dev/null
wait_rollout kz-dev dev-web 120s
wait_rollout kz-prod prod-web 120s

# Task 6 — bump prod to 4 replicas, preview with kubectl diff, then apply
sed -i 's/count: 3/count: 4/' "$OUT_DIR/overlays/prod/kustomization.yaml"
rc=0
k diff -k "$OUT_DIR/overlays/prod" > "$OUT_DIR/diff.txt" 2>&1 || rc=$?
echo "exit code: $rc" >> "$OUT_DIR/diff.txt"
k apply -k "$OUT_DIR/overlays/prod" >/dev/null
wait_rollout kz-prod prod-web 120s

# Task 7 — server-side listing of everything in the prod overlay
k get -k "$OUT_DIR/overlays/prod" > "$OUT_DIR/prod-get.txt" 2>&1 || true

# Task 8 — delete the whole dev overlay
k delete -k "$OUT_DIR/overlays/dev" >/dev/null 2>&1 || true

info "lab 17 solved"
