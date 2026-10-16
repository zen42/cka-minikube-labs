#!/usr/bin/env bash
# Lab 16 readiness — cluster up + helm installed + chart repo reachable.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command helm "run: make tools"
require_cluster
curl -sfI --max-time 10 https://stefanprodan.github.io/podinfo/index.yaml \
    >/dev/null \
    || die "cannot reach https://stefanprodan.github.io/podinfo (helm repo)"

info "READY: helm $(helm version --short 2>/dev/null) — next: ./setup.sh"
