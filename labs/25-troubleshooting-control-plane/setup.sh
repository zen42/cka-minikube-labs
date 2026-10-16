#!/usr/bin/env bash
# Lab 25 setup — back up the scheduler manifest, then BREAK it
# (kubeconfig path typo), wait for the mirror pod to crash-loop, and
# seed a deployment that can never schedule.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"
CP="$(control_plane_node)"

# safety copy of the pristine manifest — never overwrite an existing one
mkdir -p "$STATE_DIR"
if [[ ! -f "$STATE_DIR/lab25-scheduler.yaml" ]]; then
    # ssh translates \n to \r\n — strip so the restore is byte-identical
    node_ssh "$CP" \
        "sudo cat /etc/kubernetes/manifests/kube-scheduler.yaml" \
        | tr -d '\r' > "$STATE_DIR/lab25-scheduler.yaml"
fi

# if a previous run left it broken (or fixed), put a clean one in place
# first so the break is deterministic
node_ssh "$CP" \
    "sudo sed -i 's|scheduler.conf.wrong|scheduler.conf|g' \
        /etc/kubernetes/manifests/kube-scheduler.yaml" >/dev/null
wait_for "scheduler healthy before breaking" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pod \
        kube-scheduler-$CP -o \
        jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null \
        | grep -q true"

# BREAK: point --kubeconfig at a file that does not exist
node_ssh "$CP" \
    "sudo sed -i 's|--kubeconfig=/etc/kubernetes/scheduler.conf|--kubeconfig=/etc/kubernetes/scheduler.conf.wrong|' /etc/kubernetes/manifests/kube-scheduler.yaml" >/dev/null
info "waiting for kube-scheduler-$CP to crash..."
wait_for "scheduler pod broken" 180 \
    bash -c "! kubectl --context $KUBE_CONTEXT -n kube-system get pod \
        kube-scheduler-$CP -o \
        jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null \
        | grep -q true"

delete_namespace_if_exists ts-cp
ensure_namespace ts-cp
k apply -f "$LAB_DIR/manifests/stuck.yaml" >/dev/null

info "lab 25 setup done — scheduler down, 'stuck' will stay Pending"
