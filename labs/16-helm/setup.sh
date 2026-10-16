#!/usr/bin/env bash
# Lab 16 setup — clean slate: remove leftover releases + the 'helm' ns.
# The namespace is intentionally NOT created here: task 3 has the learner
# create it via `helm install --create-namespace`.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# a re-run must reset to a clean start state
for rel in webapp frontend; do
    h uninstall "$rel" -n helm >/dev/null 2>&1 || true
done
delete_namespace_if_exists helm

info "lab 16 setup done — no 'helm' namespace; tasks create it"
