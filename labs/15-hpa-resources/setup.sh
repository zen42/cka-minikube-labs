#!/usr/bin/env bash
# Lab 15 setup — clean ns autoscale.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists autoscale
ensure_namespace autoscale

info "lab 15 setup done — empty 'autoscale' namespace ready"
