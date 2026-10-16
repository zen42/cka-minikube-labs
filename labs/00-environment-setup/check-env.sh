#!/usr/bin/env bash
# Lab 00 readiness — the cluster does NOT exist yet here; check tools + host.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

missing=0
for cmd in minikube kubectl helm kustomize etcdctl jq curl make; do
    if command -v "$cmd" >/dev/null 2>&1; then
        info "found: $cmd"
    else
        error "missing: $cmd — run: make tools (CLI tools) or install $cmd"
        missing=1
    fi
done

driver=""
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    driver="docker"
elif command -v podman >/dev/null 2>&1 \
    && { sudo -n podman info >/dev/null 2>&1 || podman info >/dev/null 2>&1; }; then
    driver="podman"
fi
if [[ -n "$driver" ]]; then
    info "container driver: $driver"
else
    error "no container driver (docker or podman) is usable"
    missing=1
fi

(( $(nproc) >= 4 )) || warn "fewer than 4 CPUs available"
(( $(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo) >= 8192 )) \
    || warn "less than 8 GB RAM available"

(( missing == 0 )) || die "fix the items above, then re-run this check"
info "READY: host is prepared — next: ./setup.sh (creates the cluster)"
