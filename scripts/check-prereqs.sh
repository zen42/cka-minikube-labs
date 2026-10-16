#!/usr/bin/env bash
# check-prereqs.sh — report which host prerequisites are present.
# Exit 0 iff every required item is OK.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

FAILURES=0

ok()      { printf '  %-28s %sOK%s      %s\n' "$1" "$_C_GREEN" "$_C_RESET" "${2:-}"; }
missing() { printf '  %-28s %sMISSING%s  %s\n' "$1" "$_C_RED" "$_C_RESET" "${2:-}"; FAILURES=$(( FAILURES + 1 )); }
warned()  { printf '  %-28s %sWARN%s     %s\n' "$1" "$_C_YELLOW" "$_C_RESET" "${2:-}"; }

ver_ge() {  # ver_ge <have> <want> — dotted version compare
    [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$2" ]]
}

echo "Required tools"
echo "--------------"

# bash >= 4.4
if ver_ge "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" "4.4"; then
    ok "bash >= 4.4" "$BASH_VERSION"
else
    missing "bash >= 4.4" "found $BASH_VERSION"
fi

if command -v minikube >/dev/null 2>&1; then
    ok "minikube" "$(minikube version --short 2>/dev/null)"
else
    missing "minikube" "install from https://minikube.sigs.k8s.io/docs/start/"
fi

driver_found=""
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    driver_found="docker"
elif command -v podman >/dev/null 2>&1; then
    if sudo -n podman info >/dev/null 2>&1; then driver_found="podman (rootful via sudo -n)";
    elif podman info >/dev/null 2>&1;         then driver_found="podman (rootless)"; fi
fi
if [[ -n "$driver_found" ]]; then
    ok "container driver" "$driver_found"
else
    missing "container driver" "need docker, or podman (rootless or 'sudo -n podman')"
fi

for tool in kubectl helm kustomize etcdctl; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool" "$(command -v "$tool")"
    else
        missing "$tool" "run: scripts/install-tools.sh"
    fi
done

for tool in jq curl make; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool"
    else
        missing "$tool" "install via your package manager (e.g. apt install $tool)"
    fi
done

echo
echo "Host resources"
echo "--------------"
cpus=$(nproc)
mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
disk_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
(( cpus >= 4 ))        && ok "CPU cores (>=4)" "$cpus"        || warned "CPU cores (>=4)" "$cpus"
(( mem_mb >= 8192 ))   && ok "RAM (>=8 GB)" "${mem_mb} MB"    || warned "RAM (>=8 GB)" "${mem_mb} MB"
(( disk_gb >= 20 ))    && ok "free disk on / (>=20 GB)" "${disk_gb} GB" \
                       || warned "free disk on / (>=20 GB)" "${disk_gb} GB"

# multi-node labs need a bigger inotify-instance budget (kubelet/cAdvisor/
# containerd on every node draw from the same per-UID pool)
inotify=$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0)
if (( inotify >= 1024 )); then
    ok "fs.inotify.max_user_instances" "$inotify"
else
    warned "fs.inotify.max_user_instances" \
        "$inotify — needed by multi-node labs 14, 20, 23:"
    echo "      sudo sysctl -w fs.inotify.max_user_instances=8192"
    echo "      echo fs.inotify.max_user_instances=8192 | sudo tee /etc/sysctl.d/99-inotify.conf"
fi

echo
if (( FAILURES > 0 )); then
    error "$FAILURES required prerequisite(s) missing."
    info  "Install CLI tools with: scripts/install-tools.sh"
    exit 1
fi
info "all required prerequisites satisfied"
