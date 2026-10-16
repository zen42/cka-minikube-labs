#!/usr/bin/env bash
# Lab 21 setup — ns etcd-lab + the 'before-snapshot' marker, etcd
# client tools inside the node, and a safety copy of the etcd manifest.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"
CP="$(control_plane_node)"

# the restore rolls the WHOLE cluster back to the snapshot — warn if
# another lab's state is live
other="$(k get ns -l cka-lab --no-headers 2>/dev/null \
    | grep -v '^etcd-lab ' || true)"
if [[ -n "$other" ]]; then
    warn "other lab namespaces are live — task 4 rolls the cluster back"
    warn "to the snapshot; run their teardown first:"
    printf '%s\n' "$other" >&2
fi

delete_namespace_if_exists etcd-lab
ensure_namespace etcd-lab
k create configmap before-snapshot -n etcd-lab \
    --from-literal=marker=before \
    --dry-run=client -o yaml | k apply -f - >/dev/null

# the node has no etcdctl/etcdutl of its own (only inside the etcd
# container, which is gone mid-restore) — copy the host binaries in
ensure_node_etcd_tools

# safety copy of the static manifest — never overwrite an existing one
mkdir -p "$STATE_DIR"
if [[ ! -f "$STATE_DIR/lab21-etcd.yaml" ]]; then
    # ssh translates \n to \r\n — strip so the restore is byte-identical
    node_ssh "$CP" "sudo cat /etc/kubernetes/manifests/etcd.yaml" \
        | tr -d '\r' > "$STATE_DIR/lab21-etcd.yaml"
fi

info "lab 21 setup done — marker configmap seeded, tools in place"
