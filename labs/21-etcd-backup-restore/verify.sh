#!/usr/bin/env bash
# Lab 21 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

CP="$(control_plane_node)"

# Task 1 — health + membership recorded
check_file_contains "endpoint-health.txt reports healthy" \
    "$OUT_DIR/endpoint-health.txt" 'is healthy'
check_file_contains "members.txt lists the member" \
    "$OUT_DIR/members.txt" 'cka-labs'

# Task 2 — snapshot taken + validated + still on the node
check_file_contains "snapshot-status.txt shows key/hash table" \
    "$OUT_DIR/snapshot-status.txt" 'TOTAL'
check "snapshot.db exists on the node" \
    node_ssh "$CP" \
    "sudo test -f /var/lib/minikube/etcd-backup/snapshot.db"

# Task 3+4+5 — the restore actually rolled the data back
check_resource "configmap before-snapshot survives" \
    configmap before-snapshot -n etcd-lab
check_absent "configmap after-snapshot was rolled back" \
    configmap after-snapshot -n etcd-lab
check_file_contains "cm-after-restore.txt lists before-snapshot" \
    "$OUT_DIR/cm-after-restore.txt" 'before-snapshot'
check_fails "cm-after-restore.txt has no after-snapshot" \
    grep -q 'after-snapshot' "$OUT_DIR/cm-after-restore.txt"

# Task 4 — restore plumbing: old data dir preserved, manifest back in
# place, etcd pod + apiserver healthy
check "pre-restore data dir preserved on node" \
    node_ssh "$CP" "sudo test -d /var/lib/minikube/etcd.pre-restore"
check "etcd manifest is back in manifests/" \
    node_ssh "$CP" "sudo test -f /etc/kubernetes/manifests/etcd.yaml"
check_jsonpath "etcd static pod Running" \
    pod/etcd-"$CP" '{.status.phase}' 'Running' -n kube-system
check "apiserver /readyz ok" k get --raw=/readyz

# Task 5 — endpoint status table saved
check_file_contains "endpoint-status.txt shows the endpoint" \
    "$OUT_DIR/endpoint-status.txt" '2379'

finish_checks
