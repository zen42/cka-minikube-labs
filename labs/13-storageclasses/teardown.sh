#!/usr/bin/env bash
# Lab 13 teardown — remove lab 13 resources, restore SC standard.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists dynamic
delete_if_exists clusterrolebinding storage-provisioner-nodes
delete_if_exists clusterrole storage-provisioner-nodes
for sc in fast slow-wait keep; do
    delete_if_exists storageclass "$sc"
done
# drop Released/Available PVs whose claim lived in ns dynamic
for pv in $(k get pv -o json 2>/dev/null \
        | jq -r '.items[] | select(.spec.claimRef.namespace=="dynamic")
                 | .metadata.name' 2>/dev/null || true); do
    delete_if_exists persistentvolume "$pv"
done

# restore the pristine 'standard' StorageClass (annotations included)
if [[ -f "$STATE_DIR/13-sc-standard.json" ]]; then
    if k get storageclass standard >/dev/null 2>&1; then
        restore_object "$STATE_DIR/13-sc-standard.json"
        info "storageclass standard restored"
    fi
    rm -f "$STATE_DIR/13-sc-standard.json"
fi

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 13 teardown done"
