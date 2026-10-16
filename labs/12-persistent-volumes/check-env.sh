#!/usr/bin/env bash
# Lab 12 readiness — tools + cluster up.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_cluster

info "READY: cluster is up — next: ./setup.sh"
