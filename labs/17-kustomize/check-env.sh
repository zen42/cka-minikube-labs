#!/usr/bin/env bash
# Lab 17 readiness — cluster up + kustomize installed.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command kustomize "run: make tools"
require_cluster

info "READY: kustomize $(kustomize version 2>/dev/null) — next: ./setup.sh"
