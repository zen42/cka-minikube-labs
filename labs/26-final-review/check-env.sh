#!/usr/bin/env bash
# Lab 26 readiness — cluster up + ingress addon (task 3) +
# metrics-server (task 4 needs CPU metrics for the HPA).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster
require_addon ingress
require_addon metrics-server

info "READY: cluster + addons up — next: ./setup.sh"
