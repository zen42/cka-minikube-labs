#!/usr/bin/env bash
# Lab 08 readiness — tools + cluster + ingress addon.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl   "run: make tools"
require_command kustomize "run: make tools"
require_command openssl   "apt install openssl"
require_cluster
require_addon ingress

info "READY: cluster is up, ingress addon enabled — next: ./setup.sh"
