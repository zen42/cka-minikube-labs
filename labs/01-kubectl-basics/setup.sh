#!/usr/bin/env bash
# Lab 01 setup — seed namespaces and the leftover 'old-app' deployment.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

# clean start state: wipe leftovers — 'basics' is the learner's to create
# (task 1), so only remove a stale one; 'cleanup-me' is seeded below.
delete_namespace_if_exists basics
delete_namespace_if_exists cleanup-me

ensure_namespace cleanup-me

# leftover resource the learner is asked to clean up (task 11)
k -n cleanup-me create deployment old-app --image=nginx:1.27 --replicas=1 \
    --dry-run=client -o yaml | k apply -f - >/dev/null
wait_rollout cleanup-me old-app 120s

info "lab 01 setup done — namespaces: basics, cleanup-me (deployment old-app)"
