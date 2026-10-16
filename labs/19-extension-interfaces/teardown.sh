#!/usr/bin/env bash
# Lab 19 teardown — remove lab 19 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_if_exists volumesnapshot csi-snap -n ext
delete_if_exists pod csi-pod -n ext
delete_if_exists pvc csi-claim -n ext
delete_namespace_if_exists ext

# put the addons back the way setup found them
mk addons disable csi-hostpath-driver >/dev/null 2>&1 || true
mk addons disable volumesnapshots >/dev/null 2>&1 || true

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 19 teardown done"
