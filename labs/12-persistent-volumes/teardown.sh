#!/usr/bin/env bash
# Lab 12 teardown — remove lab 12 resources; cluster stays.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

delete_namespace_if_exists storage
for pv in pv-manual pv-shared pv-labeled pv-delete; do
    delete_if_exists persistentvolume "$pv"
done
node_ssh "$(control_plane_node)" \
    sudo rm -rf /mnt/data/pv-manual /mnt/data/pv-shared \
        /mnt/data/pv-labeled /mnt/data/pv-delete >/dev/null 2>&1 || true

if [[ -d "$OUT_DIR" ]]; then
    rm -rf "$OUT_DIR"
    info "removed $OUT_DIR"
fi

info "lab 12 teardown done"
