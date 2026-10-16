#!/usr/bin/env bash
# Lab 13 setup — back up SC standard, clean stale SCs/PVs, seed ns dynamic.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# Back up the 'standard' StorageClass BEFORE anything mutates it — and
# never overwrite an existing backup (an interrupted lab may have left the
# default annotation changed). If a backup exists, restore it so the lab
# always starts from the pristine class.
if [[ ! -f "$STATE_DIR/13-sc-standard.json" ]]; then
    backup_object storageclass standard "" "$STATE_DIR/13-sc-standard.json"
    info "storageclass standard backed up to .state/"
else
    restore_object "$STATE_DIR/13-sc-standard.json"
    info "storageclass standard restored from existing backup"
fi

# clean stale lab objects (idempotent reset)
delete_namespace_if_exists dynamic
for sc in fast slow-wait keep; do
    delete_if_exists storageclass "$sc"
done
# remove leftover PVs provisioned for claims in ns dynamic
for pv in $(k get pv -o json 2>/dev/null \
        | jq -r '.items[] | select(.spec.claimRef.namespace=="dynamic")
                 | .metadata.name' 2>/dev/null || true); do
    delete_if_exists persistentvolume "$pv"
done

ensure_namespace dynamic

info "lab 13 setup done — ns dynamic ready; 'standard' is the default SC"
