#!/usr/bin/env bash
# setup-minikube.sh — idempotent bootstrap of the shared 'cka-labs' cluster.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

lab_banner() { :; }   # top-level script: silence per-lab banner

info "bootstrapping minikube profile '$MINIKUBE_PROFILE'"

# --- driver detection ------------------------------------------------------
detect_driver() {
    if [[ -n "${MINIKUBE_DRIVER:-}" ]]; then
        printf '%s\n' "$MINIKUBE_DRIVER"; return 0
    fi
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        printf 'docker\n'; return 0
    fi
    if command -v podman >/dev/null 2>&1; then
        if sudo -n podman info >/dev/null 2>&1 || podman info >/dev/null 2>&1; then
            printf 'podman\n'; return 0
        fi
    fi
    die "no usable container driver found — install docker or podman \
(or export MINIKUBE_DRIVER=<driver>)"
}
DRIVER="$(detect_driver)"
info "driver: $DRIVER"

# --- podman quirks on this host ---------------------------------------------
podman_cmd() {
    if sudo -n podman info >/dev/null 2>&1; then printf 'sudo -n podman';
    else printf 'podman'; fi
}

aardvark_missing() {
    ! command -v aardvark-dns >/dev/null 2>&1 \
        && ! ls /usr/lib/podman/aardvark-dns /usr/libexec/podman/aardvark-dns \
               >/dev/null 2>&1
}

# Without aardvark-dns, podman networks with dns_enabled give containers a
# dead resolver. Fallback fix: pre-create the profile's network with
# --disable-dns so the node inherits the host resolver. minikube reuses an
# existing network of the same name.
ensure_podman_network() {
    local pc; pc="$(podman_cmd)"
    $pc network exists "$MINIKUBE_PROFILE" 2>/dev/null && return 0
    aardvark_missing || return 0
    info "fallback: pre-creating podman network '$MINIKUBE_PROFILE' \
with --disable-dns (node uses the host resolver)"
    $pc network create --disable-dns "$MINIKUBE_PROFILE" >/dev/null
}

# A firewall with FORWARD policy DROP (e.g. stock UFW) kills all TCP/UDP out
# of podman bridges — ICMP is explicitly allowed, so ping still works and the
# breakage is easy to miss. We only DETECT and instruct; we never touch the
# host firewall. Set CKA_EGRESS_PROBE_URL to test against another URL.
check_container_egress() {
    local pc net probe="${CKA_EGRESS_PROBE_URL:-https://registry.k8s.io/}"
    pc="$(podman_cmd)"
    if $pc network exists "$MINIKUBE_PROFILE" 2>/dev/null; then
        net="$MINIKUBE_PROFILE"
    else
        net="podman"   # default bridge
    fi
    # the image pull goes through the HOST network — always fine
    $pc image exists busybox:1.36 2>/dev/null \
        || $pc pull -q docker.io/library/busybox:1.36 >/dev/null
    $pc run --rm --network "$net" docker.io/library/busybox:1.36 \
        wget -qO /dev/null -T 5 "$probe" >/dev/null 2>&1 && return 0
    # probe failed — is it the firewall, or is the host offline too?
    if ! curl -fsS -m 5 -o /dev/null "$probe" 2>/dev/null; then
        die "the HOST cannot reach $probe either — check internet/proxy first"
    fi
    cat >&2 <<EOF

[ERROR] container egress is blocked: a container on podman network '$net'
        cannot reach $probe, but this host can.
        Classic symptom: 'ping 8.8.8.8' works inside the container but
        TCP/UDP does not — UFW ships FORWARD policy DROP and only ICMP is
        explicitly allowed.

        One-time durable fix (needs your sudo password):

        1. Add these two lines to /etc/ufw/before.rules, inside the
           *filter section, just before COMMIT:

             -A ufw-before-forward -i podman+ -j ACCEPT
             -A ufw-before-forward -o podman+ -m conntrack \\
               --ctstate ESTABLISHED,RELATED -j ACCEPT

        2. Run: sudo ufw reload

        (Broader alternative: DEFAULT_FORWARD_POLICY="ACCEPT" in
         /etc/default/ufw — allows forwarding for ALL interfaces.)

        Then re-run: make setup
EOF
    exit 1
}

# Post-start sanity check (warning only): can the node itself get out?
check_node_egress() {
    local probe="${CKA_EGRESS_PROBE_URL:-https://registry.k8s.io/}"
    node_ssh "$(control_plane_node)" \
        curl -fsS -m 5 -o /dev/null "$probe" >/dev/null 2>&1 \
        || warn "node cannot reach $probe — image pulls may fail \
(see the ufw instructions above if so)"
}

# --- host resource check (warn, never die) ----------------------------------
cpus=$(nproc)
mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
disk_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
(( cpus >= 4 ))   || warn "host has $cpus CPU (<4 recommended)"
(( mem_mb >= 8192 )) || warn "host has ${mem_mb}MB RAM (<8GB recommended)"
(( disk_gb >= 20 )) || warn "only ${disk_gb}GB free on / (<20GB recommended)"

# --- start or resume the profile -------------------------------------------
profile_exists() {
    minikube profile list -o json 2>/dev/null \
        | jq -e --arg p "$MINIKUBE_PROFILE" \
            '[.valid[]?, .invalid[]?] | any(.Name == $p)' >/dev/null 2>&1
}

cluster_running() {
    mk status 2>/dev/null | grep -q 'host: Running'
}

# --- podman egress check (detect + instruct, never mutate) -------------------
if [[ "$DRIVER" == "podman" ]]; then
    aardvark_missing \
        && info "aardvark-dns not installed — durable fix: \
sudo apt install aardvark-dns"
    check_container_egress
fi

# The node container keeps its creation-time cgroup memory.max — raising
# MINIKUBE_MEMORY in versions.env alone won't enlarge a running node.
# docker/podman update can raise the limit live (persisted in HostConfig).
ensure_node_memory() {
    local cur want_b=$(( MINIKUBE_MEMORY * 1024 * 1024 )) pc
    case "$DRIVER" in
        podman) pc="$(podman_cmd)" ;;
        docker) pc="docker" ;;
        *) return 0 ;;
    esac
    cur="$($pc inspect "$MINIKUBE_PROFILE" \
        --format '{{.HostConfig.Memory}}' 2>/dev/null || echo 0)"
    [[ "$cur" =~ ^[0-9]+$ ]] || return 0
    if (( cur > 0 && cur < want_b )); then
        info "raising node container memory limit to ${MINIKUBE_MEMORY}MiB"
        $pc update --memory "${MINIKUBE_MEMORY}m" "$MINIKUBE_PROFILE" \
            >/dev/null 2>&1 \
            || warn "could not raise container memory limit \
(driver update unsupported?)"
    fi
}

if ! profile_exists; then
    [[ "$DRIVER" == "podman" ]] && ensure_podman_network
    info "creating cluster: $MINIKUBE_PROFILE \
(k8s $KUBERNETES_VERSION, $MINIKUBE_RUNTIME, cni=$MINIKUBE_CNI)"
    minikube start -p "$MINIKUBE_PROFILE" \
        --driver="$DRIVER" \
        --container-runtime="$MINIKUBE_RUNTIME" \
        --kubernetes-version="$KUBERNETES_VERSION" \
        --cni="$MINIKUBE_CNI" \
        --nodes=1 \
        --cpus="$MINIKUBE_CPUS" \
        --memory="$MINIKUBE_MEMORY"
elif cluster_running; then
    info "profile '$MINIKUBE_PROFILE' is already running — leaving as is"
    ensure_node_memory
else
    info "profile exists but is stopped — resuming"
    minikube start -p "$MINIKUBE_PROFILE"
    ensure_node_memory
fi

# --- addons (idempotent) ----------------------------------------------------
for addon in metrics-server ingress; do
    if ! addon_enabled "$addon"; then
        info "enabling addon: $addon"
        mk addons enable "$addon" >/dev/null
    fi
done

# --- wait for the cluster to settle ----------------------------------------
calico_running() {
    k -n kube-system get pods -l k8s-app=calico-node \
        --no-headers 2>/dev/null | grep -q 'Running'
}
coredns_running() {
    k -n kube-system get pods -l k8s-app=kube-dns \
        --no-headers 2>/dev/null | grep -q 'Running'
}

wait_for "all nodes Ready" 300 all_nodes_ready
wait_for "calico-node pods running" 300 calico_running
wait_for "coredns running" 180 coredns_running
wait_for "metrics-server available" 240 \
    deploy_available kube-system metrics-server
wait_for "ingress-nginx controller available" 240 \
    deploy_available ingress-nginx ingress-nginx-controller

# --- post-start sanity: node egress (warning only) --------------------------
[[ "$DRIVER" == "podman" ]] && check_node_egress

# --- summary ----------------------------------------------------------------
echo
info "cluster is up:"
kubectl --context "$KUBE_CONTEXT" get nodes -o wide
echo
kubectl --context "$KUBE_CONTEXT" cluster-info
echo
ctx="$(kubectl config current-context 2>/dev/null || true)"
if [[ "$ctx" == "$KUBE_CONTEXT" ]]; then
    info "kubectl current-context is already '$KUBE_CONTEXT'"
else
    warn "kubectl current-context is '${ctx:-none}'."
    warn "minikube start may have switched it; to use this cluster run:"
    warn "    kubectl config use-context $KUBE_CONTEXT"
    warn "(the lab scripts themselves always use '--context $KUBE_CONTEXT')"
fi
