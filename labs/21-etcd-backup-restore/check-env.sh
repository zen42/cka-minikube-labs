#!/usr/bin/env bash
# Lab 21 readiness — cluster up + etcd tooling on the host.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command minikube
require_command etcdctl "run: make tools"
require_command etcdutl "run: make tools"
require_cluster

info "READY: etcd $(etcdctl version 2>/dev/null | head -1) — next: ./setup.sh"
