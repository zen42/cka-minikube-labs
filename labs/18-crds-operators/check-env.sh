#!/usr/bin/env bash
# Lab 18 readiness — cluster up + helm installed + jetstack repo reachable.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command helm "run: make tools"
require_cluster
curl -sfI --max-time 10 https://charts.jetstack.io >/dev/null \
    || die "cannot reach https://charts.jetstack.io (helm repo)"

info "READY: helm $(helm version --short 2>/dev/null) — next: ./setup.sh"
