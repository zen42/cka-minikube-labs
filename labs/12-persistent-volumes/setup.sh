#!/usr/bin/env bash
# Lab 12 setup — ns storage + broken PVC; wipe stale hostPath dirs.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists storage
for pv in pv-manual pv-shared pv-labeled pv-delete; do
    delete_if_exists persistentvolume "$pv"
done

# wipe stale hostPath data inside the node so a previous run's msg.txt
# cannot pre-satisfy task 3
node_ssh "$(control_plane_node)" \
    sudo rm -rf /mnt/data/pv-manual /mnt/data/pv-shared \
        /mnt/data/pv-labeled /mnt/data/pv-delete >/dev/null 2>&1 || true

ensure_namespace storage
k apply -f "$LAB_DIR/manifests/claim-broken.yaml" >/dev/null
sleep 2
info "claim-broken phase: $(k get pvc claim-broken -n storage \
    -o jsonpath='{.status.phase}') (expected: Pending)"

info "lab 12 setup done — claim-broken is Pending, no matching PV"
