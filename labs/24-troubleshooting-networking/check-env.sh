#!/usr/bin/env bash
# Lab 24 readiness — cluster up + the ingress addon (task 5 needs it).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster
require_addon ingress

info "READY: cluster + ingress-nginx up — next: ./setup.sh"
