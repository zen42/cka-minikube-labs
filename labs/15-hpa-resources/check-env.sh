#!/usr/bin/env bash
# Lab 15 readiness — cluster up + metrics-server actually serving.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster
require_addon metrics-server
wait_for "metrics-server is serving (kubectl top nodes)" 90 k top nodes

info "READY: metrics-server is up — next: ./setup.sh"
