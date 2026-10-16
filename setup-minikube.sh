#!/usr/bin/env bash
# setup-minikube.sh — idempotent bootstrap of the shared 'cka-labs' cluster.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

lab_banner() { :; }   # top-level script: silence per-lab banner

require_command minikube "install from https://minikube.sigs.k8s.io/docs/start/"
require_command kubectl  "run: scripts/install-tools.sh"
require_command jq       "install via your package manager"
require_command curl     "install via your package manager"

info "bootstrapping minikube profile '$MINIKUBE_PROFILE'"

# --- driver detection (shared helpers in common.sh) -------------------------
DRIVER="$(detect_driver)" \
    || die "no usable container driver found — install docker or podman \
(or export MINIKUBE_DRIVER=<driver>)"
apply_podman_mode "$DRIVER"
info "driver: $DRIVER"

# --- podman quirks ---------------------------------------------------------
# Podman dns_enabled networks hand containers a resolver on the network
# gateway — aardvark-dns listening on a host bridge IP. Reaching it is
# host-INPUT traffic, which a firewall with INPUT policy DROP (stock UFW)
# silently kills: node DNS dies, every image pull stalls, setup looks hung.
# aardvark-dns is therefore NOT required for this repo — instead we
# pre-create the profile's network with --disable-dns so the node inherits
# the HOST resolver (podman substitutes the real upstream servers for a
# systemd-resolved 127.0.0.53 stub). minikube reuses an existing network
# of the same name.
ensure_podman_network() {
    local pc; pc="$(podman_cmd)"
    $pc network exists "$MINIKUBE_PROFILE" 2>/dev/null && return 0
    info "pre-creating podman network '$MINIKUBE_PROFILE' with --disable-dns \
(node uses the host resolver; podman gateway DNS is unreachable behind \
INPUT DROP firewalls)"
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
(( MINIKUBE_MEMORY < 8192 )) \
    && info "host RAM ${mem_mb} MiB -> node memory ${MINIKUBE_MEMORY} MiB; \
8192 recommended, ingress-nginx may throttle"

# --- start or resume the profile -------------------------------------------
cluster_running() {
    mk status 2>/dev/null | grep -q 'host: Running'
}

# --- podman egress check (detect + instruct, never mutate) -------------------
[[ "$DRIVER" == "podman" ]] && check_container_egress

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

# An existing profile may not have been created by this script — a bare
# 'minikube start -p <profile>' (or a half-deleted profile that got resumed)
# boots minikube defaults: newest k8s, kindnet CNI. Catch that here instead
# of polling out in the calico wait below.
ensure_cluster_matches_pins() {
    local ver i problems=()
    for i in $(seq 1 15); do   # apiserver may still be waking after a resume
        ver="$(k get node "$(control_plane_node)" \
            -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null)"
        [[ -n "$ver" ]] && break
        sleep 2
    done
    [[ -n "$ver" ]] || return 0   # can't tell — let the waits below report it
    [[ "$ver" == "$KUBERNETES_VERSION" ]] \
        || problems+=("kubernetes $ver != pinned $KUBERNETES_VERSION")
    if [[ "$MINIKUBE_CNI" == "calico" ]] \
            && ! k -n kube-system get ds calico-node >/dev/null 2>&1; then
        problems+=("CNI '$MINIKUBE_CNI' missing — no calico-node daemonset \
(NetworkPolicy labs will not enforce anything)")
    fi
    (( ${#problems[@]} )) || return 0
    error "profile '$MINIKUBE_PROFILE' exists but does not match versions.env:"
    printf '  - %s\n' "${problems[@]}" >&2
    die "recreate it: make teardown-cluster && make setup"
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
    ensure_cluster_matches_pins
    ensure_node_memory
else
    info "profile exists but is stopped — resuming"
    minikube start -p "$MINIKUBE_PROFILE"
    ensure_cluster_matches_pins
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
