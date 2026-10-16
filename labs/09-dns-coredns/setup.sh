#!/usr/bin/env bash
# Lab 09 setup — back up coredns ConfigMap, seed dns/dns-other namespaces.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Back up the coredns ConfigMap BEFORE seeding — and never overwrite an
# existing backup (an interrupted lab may have left Corefile mutations).
if [[ ! -f "$STATE_DIR/09-coredns.yaml" ]]; then
    backup_object configmap coredns kube-system "$STATE_DIR/09-coredns.yaml"
    info "coredns ConfigMap backed up to $STATE_DIR/09-coredns.yaml"
else
    info "existing coredns backup kept ($STATE_DIR/09-coredns.yaml)"
fi

delete_namespace_if_exists dns
delete_namespace_if_exists dns-other
ensure_namespace dns
ensure_namespace dns-other

k apply -f "$LAB_DIR/manifests/web.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/client.yaml" >/dev/null
k apply -f "$LAB_DIR/manifests/api.yaml" >/dev/null
wait_rollout dns web 180s
wait_rollout dns-other api 180s
wait_pod_ready dns client 180s

info "lab 09 setup done — web+client in 'dns', api in 'dns-other'"
