#!/usr/bin/env bash
# Lab 18 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Task 1 — hand-written CRD crontabs.stable.example.com
k apply -f - >/dev/null <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: crontabs.stable.example.com
spec:
  group: stable.example.com
  scope: Namespaced
  names:
    plural: crontabs
    singular: crontab
    kind: CronTab
    shortNames: [ct]
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              cronSpec:
                type: string
              image:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 10
    additionalPrinterColumns:
    - name: Spec
      type: string
      jsonPath: .spec.cronSpec
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
EOF
k wait --for=condition=Established \
    crd/crontabs.stable.example.com --timeout=60s >/dev/null
# discovery/openapi lags a few seconds behind CRD creation
wait_for "crontabs discoverable" 60 \
    bash -c "kubectl --context $KUBE_CONTEXT explain crontab.spec \
        >/dev/null 2>&1"

# Task 2 — explain the CRD's spec into a file
k explain crontab.spec > "$OUT_DIR/explain.txt"

# Task 3 — two valid CRs
k apply -n crd-demo -f - >/dev/null <<'EOF'
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: my-new-cron-object
spec:
  cronSpec: "* * * * */5"
  image: some-cron-image
  replicas: 1
---
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: my-other-cron
spec:
  cronSpec: "*/10 * * * *"
  image: some-cron-image
  replicas: 3
EOF

# Task 4 — an invalid CR (replicas 20 > max 10) must be REJECTED.
# The rejected manifest + the apiserver's error are saved as evidence.
cat > "$OUT_DIR/invalid.yaml" <<'EOF'
apiVersion: stable.example.com/v1
kind: CronTab
metadata:
  name: invalid-cron
  namespace: crd-demo
spec:
  cronSpec: "* * * * *"
  image: some-cron-image
  replicas: 20
EOF
k apply -f "$OUT_DIR/invalid.yaml" > "$OUT_DIR/invalid-error.txt" 2>&1 \
    || true

# Task 5 — shortName + printer columns
k get ct -n crd-demo \
    -o custom-columns=NAME:.metadata.name,SPEC:.spec.cronSpec,REPLICAS:.spec.replicas \
    > "$OUT_DIR/ct.txt"

# Task 6 — the API group now appears in discovery
k api-resources --api-group=stable.example.com \
    > "$OUT_DIR/api-resources.txt"

# Task 7 — install the cert-manager operator via helm
h repo add jetstack https://charts.jetstack.io >/dev/null
h repo update >/dev/null
h upgrade --install cert-manager jetstack/cert-manager \
    -n cert-manager --create-namespace \
    --version "$CERT_MANAGER_VERSION" --set crds.enabled=true >/dev/null
for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
    k -n cert-manager wait --for=condition=Available "deploy/$d" \
        --timeout=180s >/dev/null
done
info "cert-manager deployed"

# Task 8 — use the operator's CRDs: self-signed ClusterIssuer + a cert
k apply -f - >/dev/null <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: demo-cert
  namespace: crd-demo
spec:
  secretName: demo-cert-tls
  dnsNames: [demo.example.com]
  duration: 24h
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
EOF
k -n crd-demo wait --for=condition=Ready certificate/demo-cert \
    --timeout=120s >/dev/null
info "certificate demo-cert is Ready"

# Task 9 — count the CRDs the operator installed
k get crd | grep cert-manager > "$OUT_DIR/cert-manager-crds.txt"

# Task 10 — describe one of them
k describe crd certificates.cert-manager.io \
    > "$OUT_DIR/describe-crd.txt" 2>&1 || true

info "lab 18 solved"
