#!/usr/bin/env bash
# Lab 00 setup — this is where the cka-labs cluster gets created.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

mkdir -p "$OUT_DIR"
"$REPO_ROOT/setup-minikube.sh"
info "lab 00 setup done — cluster '$MINIKUBE_PROFILE' is up"
