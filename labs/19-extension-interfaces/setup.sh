#!/usr/bin/env bash
# Lab 19 setup — clean ns ext; any leftover CSI objects die with it.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

delete_namespace_if_exists ext
ensure_namespace ext

info "lab 19 setup done — empty 'ext' namespace ready"
