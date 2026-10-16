#!/usr/bin/env bash
# Lab 12 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — pv-manual spec
check_jsonpath "pv-manual hostPath is set" \
    pv/pv-manual '{.spec.hostPath.path}' '/mnt/data/pv-manual'
check_jsonpath "pv-manual reclaim is Retain" \
    pv/pv-manual '{.spec.persistentVolumeReclaimPolicy}' 'Retain'
check_jsonpath "pv-manual class is manual" \
    pv/pv-manual '{.spec.storageClassName}' 'manual'

# Task 2 — claim-manual bound to pv-manual
check_jsonpath "claim-manual is Bound" \
    pvc/claim-manual '{.status.phase}' 'Bound' -n storage
check_jsonpath "claim-manual bound to pv-manual" \
    pvc/claim-manual '{.spec.volumeName}' 'pv-manual' -n storage

# Task 3 — writer wrote the file (writer may be deleted by task 4 —
# verify via reader/msg.txt below AND the hostPath content via reader)
check "msg.txt exists on the volume" \
    bash -c "kubectl --context $KUBE_CONTEXT exec reader -n storage -- \
        cat /data/msg.txt 2>/dev/null | grep -q 'hello from writer'"

# Task 4 — writer gone, reader running, msg.txt content saved
check_absent "writer pod deleted" pod writer -n storage
check_jsonpath "reader is Running" \
    pod/reader '{.status.phase}' 'Running' -n storage
check_file_contains "msg.txt holds writer's message" \
    "$OUT_DIR/msg.txt" 'hello from writer'

# Task 5 — claim-broken bound to pv-shared
check_jsonpath "claim-broken is Bound" \
    pvc/claim-broken '{.status.phase}' 'Bound' -n storage
check_jsonpath "claim-broken bound to pv-shared" \
    pvc/claim-broken '{.spec.volumeName}' 'pv-shared' -n storage

# Task 6 — claim-gold bound specifically to pv-labeled
check_jsonpath "claim-gold bound to pv-labeled" \
    pvc/claim-gold '{.spec.volumeName}' 'pv-labeled' -n storage

# Task 7 — claim-delete gone; recorded phase matches the cluster
check_absent "claim-delete deleted" pvc claim-delete -n storage
_file_status="$(tr -d '[:space:]' < "$OUT_DIR/pv-delete-status.txt" \
    2>/dev/null || true)"
check_match "pv-delete-status.txt recorded a status" "$_file_status" \
    'Failed|Released'
_pv_status="$(k get pv pv-delete -o jsonpath='{.status.phase}' \
    2>/dev/null || true)"
check_eq "pv-delete status matches the file" "$_pv_status" "$_file_status"

# Task 8 — pvs.txt sorted listing
check_file_contains "pvs.txt lists pv-manual" \
    "$OUT_DIR/pvs.txt" 'pv-manual'
check_file_contains "pvs.txt lists pv-shared" \
    "$OUT_DIR/pvs.txt" 'pv-shared'

# Task 9 — scratch emptyDir medium Memory
check_jsonpath "scratch emptyDir medium is Memory" \
    pod/scratch '{.spec.volumes[0].emptyDir.medium}' 'Memory' -n storage
check_jsonpath "scratch emptyDir sizeLimit is 100Mi" \
    pod/scratch '{.spec.volumes[0].emptyDir.sizeLimit}' '100Mi' -n storage

finish_checks
