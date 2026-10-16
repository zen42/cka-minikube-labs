#!/usr/bin/env bash
# Lab 18 teardown — remove lab 18 resources; cluster stays.
# Order matters: delete CRs/issuers first, then the helm release,
# then the CRDs the chart installed, then our hand-written CRD.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_if_exists certificate demo-cert -n crd-demo
delete_if_exists secret demo-cert-tls -n crd-demo
delete_if_exists clusterissuer selfsigned
h uninstall cert-manager -n cert-manager >/dev/null 2>&1 || true
delete_namespace_if_exists cert-manager
h repo remove jetstack >/dev/null 2>&1 || true
k delete crd -l app.kubernetes.io/name=cert-manager \
    --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
for crd in certificates.cert-manager.io certificaterequests.cert-manager.io \
    challenges.acme.cert-manager.io clusterissuers.cert-manager.io \
    issuers.cert-manager.io orders.acme.cert-manager.io; do
    delete_if_exists crd "$crd"
done
delete_if_exists crd crontabs.stable.example.com
delete_namespace_if_exists crd-demo

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 18 teardown done"
