#!/usr/bin/env bash
# Lab 14 readiness — cluster up; warn about the extra node memory.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster

if (( "$(minikube_node_count)" < 3 )); then
    warn "setup will add 2 worker nodes (~2x the minikube memory allocation)"
fi

info "READY: cluster is up — next: ./setup.sh"
