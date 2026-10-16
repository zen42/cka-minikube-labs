#!/usr/bin/env bash
# Lab 13 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — files saved; default-sc.txt == standard is checked at the END
# (task 6 legitimately changes the default — the file must hold what was
# observed at task-1 time, i.e. 'standard')
check_file_contains "storageclasses.txt lists classes" \
    "$OUT_DIR/storageclasses.txt" 'standard'
check_eq "default-sc.txt recorded 'standard'" \
    "$(tr -d '[:space:]' < "$OUT_DIR/default-sc.txt" 2>/dev/null)" "standard"

# Task 2 — claim-dynamic bound via standard
check_jsonpath "claim-dynamic class is standard" \
    pvc/claim-dynamic '{.spec.storageClassName}' 'standard' -n dynamic
check_jsonpath "claim-dynamic is Bound" \
    pvc/claim-dynamic '{.status.phase}' 'Bound' -n dynamic
_dynpv="$(k get pvc claim-dynamic -n dynamic \
    -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)"
check "PV for claim-dynamic exists and is class standard" \
    bash -c "kubectl --context $KUBE_CONTEXT get pv '$_dynpv' \
        -o jsonpath='{.spec.storageClassName}' 2>/dev/null \
        | grep -qx standard"

# Task 3 — fast spec
check_jsonpath "fast provisioner is minikube-hostpath" \
    storageclass/fast '{.provisioner}' 'k8s.io/minikube-hostpath'
check_jsonpath "fast allows expansion" \
    storageclass/fast '{.allowVolumeExpansion}' 'true'
check_jsonpath "fast binding mode is Immediate" \
    storageclass/fast '{.volumeBindingMode}' 'Immediate'

# Task 4 — slow-wait is WFFC (final claim state checked with task 5)
check_jsonpath "slow-wait binding mode is WaitForFirstConsumer" \
    storageclass/slow-wait '{.volumeBindingMode}' 'WaitForFirstConsumer'

# Task 5 — provisioner SA granted node read; consumer running; bound
check_jsonpath "storage-provisioner-nodes CRB subject is kube-system/storage-provisioner" \
    clusterrolebinding/storage-provisioner-nodes \
    '{.subjects[0].namespace}/{.subjects[0].name}' \
    'kube-system/storage-provisioner'
check_jsonpath "consumer is Running" \
    pod/consumer '{.status.phase}' 'Running' -n dynamic
check_jsonpath "claim-wait is Bound" \
    pvc/claim-wait '{.status.phase}' 'Bound' -n dynamic

# Task 6 — exactly one default, and it is fast
_default="$(k get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' \
    2>/dev/null | tr -d '[:space:]' || true)"
check_eq "fast is the only default StorageClass" "$_default" "fast"
check_jsonpath "standard is no longer default" \
    storageclass/standard \
    '{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' \
    'false'

# Task 7 — claim-fast landed on fast
check_jsonpath "claim-fast class is fast" \
    pvc/claim-fast '{.spec.storageClassName}' 'fast' -n dynamic
check_jsonpath "claim-fast is Bound" \
    pvc/claim-fast '{.status.phase}' 'Bound' -n dynamic

# Task 8 — expansion requested (status may lag on minikube-hostpath)
check_jsonpath "claim-fast requests 2Gi" \
    pvc/claim-fast '{.spec.resources.requests.storage}' '2Gi' -n dynamic

# Task 9 — claim-retain gone; its PV is Released
check_absent "claim-retain deleted" pvc claim-retain -n dynamic
_released="$(k get pv -o jsonpath='{.items[?(@.spec.claimRef.name=="claim-retain")].status.phase}' \
    2>/dev/null | tr -d '[:space:]' || true)"
check_eq "a Released PV remains for claim-retain" "$_released" "Released"

# Task 10 — PV name file matches the claim
check_eq "claim-dynamic-pv.txt matches spec.volumeName" \
    "$(tr -d '[:space:]' < "$OUT_DIR/claim-dynamic-pv.txt" 2>/dev/null)" \
    "$_dynpv"

finish_checks
