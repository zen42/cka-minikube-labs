#!/usr/bin/env bash
# Lab 18 setup — clean slate for the CRD + operator lab.
# ns crd-demo is seeded; ns cert-manager is left to task 7's
# `helm install --create-namespace`.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# reset leftovers from a previous run (reverse install order)
h uninstall cert-manager -n cert-manager >/dev/null 2>&1 || true
delete_if_exists clusterissuer selfsigned
delete_namespace_if_exists cert-manager
k delete crd -l app.kubernetes.io/name=cert-manager \
    --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
for crd in certificates.cert-manager.io certificaterequests.cert-manager.io \
    challenges.acme.cert-manager.io clusterissuers.cert-manager.io \
    issuers.cert-manager.io orders.acme.cert-manager.io; do
    delete_if_exists crd "$crd"
done
delete_if_exists crd crontabs.stable.example.com
delete_namespace_if_exists crd-demo

ensure_namespace crd-demo

info "lab 18 setup done — empty 'crd-demo' namespace ready"
