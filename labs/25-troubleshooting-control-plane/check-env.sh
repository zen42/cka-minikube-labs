#!/usr/bin/env bash
# Lab 25 readiness — cluster up + node ssh access.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command minikube
require_cluster

info "READY: cluster is up — next: ./setup.sh"
