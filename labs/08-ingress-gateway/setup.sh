#!/usr/bin/env bash
# Lab 08 setup — NGF control plane (if missing) + shop/blog backends.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# --- infrastructure: Gateway API CRDs + NGINX Gateway Fabric --------------
# Skip only if NGF is truly healthy: a partial install (e.g. deploy.yaml
# applied without NGF's own CRDs) leaves the controller crash-looping while
# GatewayClass 'nginx' still exists.
if deploy_available nginx-gateway nginx-gateway \
        && k get crd nginxgateways.gateway.nginx.org >/dev/null 2>&1; then
    info "NGF control plane already healthy — skipping install"
else
    info "installing Gateway API CRDs (bundled in NGF $NGF_VERSION)..."
    kustomize build \
        "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=${NGF_VERSION}" \
        | k apply -f - >/dev/null
    # NGF deploy.yaml needs NGF's own CRDs (NginxGateway, NginxProxy, …) —
    # install them server-side as the NGF docs do.
    info "installing NGF CRDs..."
    k apply --server-side \
        -f "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/${NGF_VERSION}/deploy/crds.yaml" \
        >/dev/null
    info "installing NGINX Gateway Fabric $NGF_VERSION..."
    k apply -f "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/${NGF_VERSION}/deploy/default/deploy.yaml" \
        >/dev/null
    wait_for "nginx-gateway deployment available" 300 \
        deploy_available nginx-gateway nginx-gateway
    wait_for "GatewayClass nginx Accepted" 120 \
        bash -c "kubectl --context $KUBE_CONTEXT get gatewayclass nginx \
            -o jsonpath='{.status.conditions[?(@.type==\"Accepted\")].status}' \
            2>/dev/null | grep -q True"
fi

# ingress-nginx 'reuseport' blackholes roughly half of new connections under
# podman+containerd: after each config reload, drained workers keep their
# per-worker listen sockets and the kernel keeps hashing new connections onto
# them (they sit in the accept backlog forever) — and the addon's 1s probes
# kill the controller under memory stalls. Environment quirks, see AGENTS.md.
harden_ingress_nginx

# --- lab resources ---------------------------------------------------------
delete_namespace_if_exists ingress
ensure_namespace ingress

k apply -f "$LAB_DIR/manifests/shop.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/blog.yaml" >/dev/null
wait_rollout ingress shop 180s
wait_rollout ingress blog 180s

info "lab 08 setup done — shop/blog running; NGF control plane ready"
