#!/usr/bin/env bash
# Lab 07 readiness — tools + cluster up + Calico enforces policies.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster

# NetworkPolicy is only enforced by a policy-capable CNI (calico here).
k -n kube-system get pods -l k8s-app=calico-node --no-headers 2>/dev/null \
    | grep -q . \
    || die "calico-node pods not found — NetworkPolicy needs a policy-aware \
CNI (recreate the cluster with: make reset-cluster)"

info "READY: cluster is up, Calico CNI present — next: ./setup.sh"
