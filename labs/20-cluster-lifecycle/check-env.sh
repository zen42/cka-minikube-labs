#!/usr/bin/env bash
# Lab 20 readiness — cluster up; warn about the extra node memory and the
# host inotify limit that multi-node joins need.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster

if (( "$(minikube_node_count)" < 3 )); then
    warn "setup will add 2 worker nodes (~2x the minikube memory allocation)"
fi
_max="$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0)"
if (( _max > 0 && _max < 1024 )); then
    warn "fs.inotify.max_user_instances=$_max is too low for multi-node"
    warn "run once: sudo sysctl -w fs.inotify.max_user_instances=8192"
fi

info "READY: cluster is up — next: ./setup.sh"
