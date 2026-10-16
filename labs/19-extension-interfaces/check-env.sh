#!/usr/bin/env bash
# Lab 19 readiness — cluster up + jq for API output.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command minikube
require_command jq
require_cluster

info "READY: cluster reachable — next: ./setup.sh"
