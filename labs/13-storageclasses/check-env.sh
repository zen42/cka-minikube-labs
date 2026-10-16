#!/usr/bin/env bash
# Lab 13 readiness — tools + cluster + storage addons.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

require_command kubectl "run: make tools"
require_command jq      "apt install jq"
require_cluster
require_addon storage-provisioner
require_addon default-storageclass

info "READY: cluster is up, storage addons enabled — next: ./setup.sh"
