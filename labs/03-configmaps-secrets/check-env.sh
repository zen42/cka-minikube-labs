#!/usr/bin/env bash
# Lab 03 readiness — tools + cluster up.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command openssl "apt install openssl"
require_command base64  "part of coreutils"
require_cluster

info "READY: cluster is up — next: ./setup.sh"
