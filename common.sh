#!/usr/bin/env bash
# common.sh — shared helpers for the CKA minikube lab suite.
# Sourced (never executed) by every lab script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"
# Must be safe under `set -euo pipefail`.

# --------------------------------------------------------------------------
# Globals
# --------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
source "$REPO_ROOT/versions.env"

[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

KUBE_CONTEXT="$MINIKUBE_PROFILE"
PROGRESS_DIR="$REPO_ROOT/.progress"
STATE_DIR="$REPO_ROOT/.state"   # backups of cluster objects labs mutate (gitignored)

# LAB_DIR: directory of the script that sourced us, unless overridden
# (the Makefile exports LAB_DIR so it can drive lab scripts directly).
if [[ -z "${LAB_DIR:-}" ]]; then
    _caller="${BASH_SOURCE[1]:-}"
    if [[ -n "$_caller" ]]; then
        LAB_DIR="$(cd "$(dirname "$_caller")" && pwd)"
    else
        LAB_DIR="$REPO_ROOT"
    fi
fi
_lab_base="$(basename "$LAB_DIR")"
if [[ "$_lab_base" =~ ^[0-9]{2}- ]]; then
    LAB_ID="${_lab_base:0:2}"
    LAB_SLUG="${_lab_base:3}"
else
    LAB_ID="${LAB_ID:-}"
    LAB_SLUG="${_lab_base}"
fi
LAB_NAME="Lab ${LAB_ID:-??} - ${LAB_SLUG}"
OUT_DIR="${CKA_OUT:-$HOME/cka-labs-out}${LAB_ID:+/$LAB_ID}"

# --------------------------------------------------------------------------
# Logging (colors only on a TTY; diagnostics go to stderr)
# --------------------------------------------------------------------------
if [[ -t 1 ]]; then
    _C_BLUE=$'\033[0;34m'; _C_YELLOW=$'\033[0;33m'; _C_RED=$'\033[0;31m'
    _C_GREEN=$'\033[0;32m'; _C_BOLD=$'\033[1m'; _C_RESET=$'\033[0m'
else
    _C_BLUE='' _C_YELLOW='' _C_RED='' _C_GREEN='' _C_BOLD='' _C_RESET=''
fi

info()  { printf '%s[INFO]%s  %s\n'  "$_C_BLUE"   "$_C_RESET" "$*"; }
warn()  { printf '%s[WARN]%s  %s\n'  "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n'  "$_C_RED"    "$_C_RESET" "$*" >&2; }
die()   { local msg="$1" code="${2:-1}"; error "$msg"; exit "$code"; }

lab_banner() {
    printf '%s== %s ==%s\n' "$_C_BOLD" "$LAB_NAME" "$_C_RESET"
}

# --------------------------------------------------------------------------
# kubectl / minikube wrappers — always pinned to the lab context
# --------------------------------------------------------------------------
k()  { kubectl --context "$KUBE_CONTEXT" "$@"; }
mk() { minikube -p "$MINIKUBE_PROFILE" "$@"; }
# helm has no --context flag; it honors --kube-context (defaults to the
# user's current context, which may not be the lab cluster).
h()  { helm --kube-context "$KUBE_CONTEXT" "$@"; }

# node_ssh <node> <command string...>
node_ssh() {
    local node="$1"; shift
    mk ssh -n "$node" -- "$@"
}

control_plane_node() { printf '%s\n' "$MINIKUBE_PROFILE"; }

# profile_exists — predicate: the lab minikube profile exists (valid or not).
profile_exists() {
    minikube profile list -o json 2>/dev/null \
        | jq -e --arg p "$MINIKUBE_PROFILE" \
            '[.valid[]?, .invalid[]?] | any(.Name == $p)' >/dev/null 2>&1
}

# podman_cmd — prints the working podman invocation: 'sudo -n podman' on
# hosts where only rootful podman is passwordless. Callers must first check
# podman is usable (podman info / sudo -n podman info).
podman_cmd() {
    if sudo -n podman info >/dev/null 2>&1; then printf 'sudo -n podman';
    else printf 'podman'; fi
}

# --- driver detection ---------------------------------------------------------
# Called only by setup/teardown/check-prereqs/lab00 check-env — never at
# source time (common.sh is sourced by every lab script; keep it cheap).
docker_usable()         { command -v docker >/dev/null 2>&1 \
                          && docker info >/dev/null 2>&1; }
podman_rootful_usable() { command -v podman >/dev/null 2>&1 \
                          && sudo -n podman info >/dev/null 2>&1; }
podman_rootless_usable(){ command -v podman >/dev/null 2>&1 \
                          && podman info >/dev/null 2>&1; }

# detect_driver — prints 'docker' or 'podman'; honours $MINIKUBE_DRIVER.
# Returns 1 (prints nothing) when nothing is usable — callers decide to die.
detect_driver() {
    if [[ -n "${MINIKUBE_DRIVER:-}" ]]; then
        printf '%s\n' "$MINIKUBE_DRIVER"; return 0
    fi
    docker_usable         && { printf 'docker\n'; return 0; }
    podman_rootful_usable  || podman_rootless_usable \
                          || return 1
    printf 'podman\n'
}

# apply_podman_mode [driver] — when the driver is podman, rootful is NOT
# usable and rootless IS: export MINIKUBE_ROOTLESS=true so minikube
# start/delete/node add all run rootless. Otherwise leaves the env alone.
# Rootless is experimental — the extra checks below warn, never die.
apply_podman_mode() {
    local driver="${1:-$(detect_driver 2>/dev/null || true)}"
    [[ "$driver" == "podman" ]] || return 0
    podman_rootful_usable && return 0   # rootful wins: minikube's default
    podman_rootless_usable || return 0
    export MINIKUBE_ROOTLESS=true
    warn "using rootless podman (experimental — less tested than rootful)"
    if [[ "${MINIKUBE_RUNTIME:-containerd}" != "containerd" ]]; then
        warn "rootless podman works best with MINIKUBE_RUNTIME=containerd \
(currently '${MINIKUBE_RUNTIME:-unset}')"
    fi
    local ctrlf="/sys/fs/cgroup/user.slice/user-${UID}.slice/user@${UID}.service/cgroup.controllers"
    if [[ -f "$ctrlf" ]]; then
        local c
        for c in cpu memory pids; do
            grep -qw "$c" "$ctrlf" \
                || warn "rootless podman: cgroup v2 controller '$c' is not \
delegated to your user — see https://minikube.sigs.k8s.io/docs/drivers/podman/"
        done
    else
        warn "rootless podman: cannot determine cgroup v2 delegation \
($ctrlf missing) — see https://minikube.sigs.k8s.io/docs/drivers/podman/"
    fi
}

minikube_node_count() {
    k get nodes --no-headers 2>/dev/null | wc -l
}

# ensure_minikube_nodes <n> — add --worker nodes until the cluster has n.
ensure_minikube_nodes() {
    local want="$1" have
    # Extra kubelets need inotify instances — the host default (128) is
    # shared per-UID across every container and is quickly exhausted, which
    # kills the worker's kubelet at join time ("inotify_init: too many open
    # files"). Detect and instruct; never mutate the host ourselves.
    local max_inst
    max_inst="$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0)"
    if (( want > 1 && max_inst > 0 && max_inst < 1024 )); then
        warn "fs.inotify.max_user_instances=$max_inst is too low for $want nodes"
        warn "run once: sudo sysctl -w fs.inotify.max_user_instances=8192"
        warn "persist:    echo fs.inotify.max_user_instances=8192 | sudo tee /etc/sysctl.d/99-inotify.conf"
    fi
    have="$(minikube_node_count)"
    while (( have < want )); do
        info "adding worker node ($((have + 1))/$want)..."
        mk node add --worker >/dev/null
        have="$(minikube_node_count)"
    done
    # `minikube node add` flips the cluster's own addons to "disabled" in
    # the addon registry (storage-provisioner, default-storageclass,
    # ingress can all lose their deployments). Re-enable the set
    # setup-minikube.sh turns on — idempotent, also covers nodes added
    # by hand.
    local addon
    for addon in storage-provisioner default-storageclass ingress \
            metrics-server; do
        if ! addon_enabled "$addon"; then
            info "re-enabling addon '$addon' (disabled by node add)"
            mk addons enable "$addon" >/dev/null
            case "$addon" in
                storage-provisioner)
                    # it's a bare pod (no Deployment) and created
                    # asynchronously — retry through the not-found window
                    wait_for "storage-provisioner pod Running" 180 \
                        bash -c "kubectl --context $KUBE_CONTEXT \
                            -n kube-system get pod storage-provisioner \
                            -o jsonpath='{.status.phase}' 2>/dev/null \
                            | grep -q Running" ;;
                ingress)
                    wait_for "ingress-nginx controller redeployed" 180 \
                        bash -c "kubectl --context $KUBE_CONTEXT \
                            -n ingress-nginx rollout status \
                            deployment/ingress-nginx-controller \
                            --timeout=15s >/dev/null 2>&1" ;;
            esac
        fi
    done
    info "waiting for $want node(s) to become Ready..."
    k wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
}

# --------------------------------------------------------------------------
# Requirements
# --------------------------------------------------------------------------
require_command() {
    local cmd="$1" hint="${2:-}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "required command not found: $cmd${hint:+ — $hint}"
    fi
}

require_cluster() {
    profile_exists \
        || die "minikube profile '$MINIKUBE_PROFILE' does not exist — run: make setup"
    local status
    status="$(mk status -o json 2>/dev/null || true)"
    [[ -n "$status" ]] || die "cannot read minikube status — run: make setup"
    # multi-node profiles emit an array — the control-plane entry is first
    status="$(jq 'if type == "array" then .[0] else . end' <<<"$status")"
    for comp in Host Kubelet APIServer; do
        jq -e ".${comp} == \"Running\"" <<<"$status" >/dev/null 2>&1 \
            || die "minikube $comp is not Running — run: make setup (or: make start)"
    done
    [[ "$(k get --raw=/readyz 2>/dev/null)" == "ok" ]] \
        || die "apiserver /readyz is not ok — run: make setup"
}

# addon_enabled <name> — predicate (0 = enabled, 1 = not/unknown).
addon_enabled() {
    local name="$1"
    mk addons list -o json 2>/dev/null \
        | jq -e --arg a "$name" '.[$a].Status == "enabled"' >/dev/null 2>&1
}

require_addon() {
    local name="$1"
    addon_enabled "$name" \
        || die "addon '$name' is not enabled — run: make setup"
}

# all_nodes_ready — predicate: at least one node and every node Ready.
all_nodes_ready() {
    local out
    out="$(k get nodes --no-headers 2>/dev/null)" || return 1
    [[ -n "$out" ]] || return 1
    ! grep -qv ' Ready ' <<<"$out"
}

# deploy_available <ns> <deployment> — predicate.
deploy_available() {
    local ns="$1" deploy="$2" avail
    avail="$(k -n "$ns" get deploy "$deploy" \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
    [[ -n "$avail" && "$avail" != "0" ]]
}

require_nodes() {
    local want="$1" have
    have="$(minikube_node_count)"
    (( have >= want )) \
        || die "cluster has $have node(s), lab needs $want — run: make lab-$LAB_ID (setup adds nodes)"
}

# --------------------------------------------------------------------------
# Namespaces / resources
# --------------------------------------------------------------------------
ensure_namespace() {
    local ns="$1"
    if ! k get namespace "$ns" >/dev/null 2>&1; then
        k create namespace "$ns" >/dev/null
    fi
    k label namespace "$ns" "cka-lab=${LAB_ID:-manual}" --overwrite >/dev/null
}

delete_namespace_if_exists() {
    local ns="$1" i
    if k get namespace "$ns" >/dev/null 2>&1; then
        info "deleting namespace $ns"
        k delete namespace "$ns" --wait=true --timeout=120s >/dev/null 2>&1 || true
        # delete --wait can return while the ns is still Terminating;
        # a follow-on ensure_namespace + create would hit "Forbidden:
        # ... being terminated"
        for i in $(seq 1 60); do
            k get namespace "$ns" >/dev/null 2>&1 || break
            sleep 2
        done
    fi
}

# delete_if_exists <kind> <name> [-n <ns>]
delete_if_exists() {
    local kind="$1" name="$2"; shift 2
    k delete "$kind" "$name" --ignore-not-found --wait=true --timeout=60s "$@" >/dev/null 2>&1 || true
}

# wait_for <desc> <timeout_s> <cmd...> — poll every 2s until cmd exits 0.
wait_for() {
    local desc="$1" timeout="$2"; shift 2
    local deadline=$(( SECONDS + timeout ))
    info "waiting (up to ${timeout}s): $desc"
    until "$@" >/dev/null 2>&1; do
        (( SECONDS < deadline )) || { error "timed out (${timeout}s) waiting for: $desc"; return 1; }
        sleep 2
    done
    info "ready: $desc"
}

wait_rollout() {
    local ns="$1" deploy="$2" timeout="${3:-120s}"
    k -n "$ns" rollout status "deployment/$deploy" --timeout="$timeout" >/dev/null
    info "rollout complete: $ns/$deploy"
}

wait_pod_ready() {
    local ns="$1" pod="$2" timeout="${3:-120s}"
    k -n "$ns" wait --for=condition=Ready "pod/$pod" --timeout="$timeout" >/dev/null
    info "pod ready: $ns/$pod"
}

pod_phase() {
    k -n "$1" get pod "$2" -o jsonpath='{.status.phase}' 2>/dev/null || true
}

# --------------------------------------------------------------------------
# Assertion API (verify.sh only)
# --------------------------------------------------------------------------
CHECKS_TOTAL=0
CHECKS_FAILED=0
FAILED_LIST=()

pass() {
    CHECKS_TOTAL=$(( CHECKS_TOTAL + 1 ))
    printf '  %s[PASS]%s %s\n' "$_C_GREEN" "$_C_RESET" "$1"
}

fail() {
    CHECKS_TOTAL=$(( CHECKS_TOTAL + 1 ))
    CHECKS_FAILED=$(( CHECKS_FAILED + 1 ))
    FAILED_LIST+=("$1")
    printf '  %s[FAIL]%s %s\n' "$_C_RED" "$_C_RESET" "$1"
}

# check "<desc>" <cmd...> — pass iff cmd exits 0 (output suppressed).
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

# check_fails "<desc>" <cmd...> — pass iff cmd exits NON-zero.
check_fails() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then fail "$desc"; else pass "$desc"; fi
}

check_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc (expected '$expected', got '$actual')"
    fi
}

check_match() {
    local desc="$1" actual="$2" regex="$3"
    if [[ "$actual" =~ $regex ]]; then
        pass "$desc"
    else
        fail "$desc ('$actual' does not match /$regex/)"
    fi
}

check_file_contains() {
    local desc="$1" file="$2" regex="$3"
    if [[ ! -f "$file" ]]; then
        fail "$desc (file missing: $file)"
    elif grep -Eq "$regex" "$file"; then
        pass "$desc"
    else
        fail "$desc ($file lacks /$regex/)"
    fi
}

# check_resource "<desc>" <kind> <name> [-n <ns>]
check_resource() {
    local desc="$1" kind="$2" name="$3"; shift 3
    check "$desc" k get "$kind" "$name" "$@"
}

# check_absent "<desc>" <kind> <name> [-n <ns>]
check_absent() {
    local desc="$1" kind="$2" name="$3"; shift 3
    if k get "$kind" "$name" "$@" >/dev/null 2>&1; then
        fail "$desc ($kind/$name still exists)"
    else
        pass "$desc"
    fi
}

# check_jsonpath "<desc>" <kind>/<name> "<jsonpath>" "<expected>" [-n <ns>]
check_jsonpath() {
    local desc="$1" res="$2" jp="$3" expected="$4"; shift 4
    local actual
    actual="$(k get "$res" -o "jsonpath=$jp" "$@" 2>/dev/null \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\n' || true)"
    check_eq "$desc" "$actual" "$expected"
}

# finish_checks — always the last line of verify.sh; exits 0 or 1.
finish_checks() {
    echo
    if (( CHECKS_FAILED == 0 )); then
        printf '%s%d/%d checks passed%s — %s complete.\n' \
            "$_C_GREEN" "$CHECKS_TOTAL" "$CHECKS_TOTAL" "$_C_RESET" "$LAB_NAME"
        mark_lab_complete
        exit 0
    fi
    printf '%s%d/%d checks passed; %d failed:%s\n' \
        "$_C_RED" "$(( CHECKS_TOTAL - CHECKS_FAILED ))" "$CHECKS_TOTAL" \
        "$CHECKS_FAILED" "$_C_RESET"
    local item
    for item in "${FAILED_LIST[@]}"; do
        printf '  - %s\n' "$item"
    done
    printf 'Hint: re-read %s/README.md and %s/SOLUTION.md, then re-run ./verify.sh\n' \
        "$LAB_DIR" "$LAB_DIR"
    exit 1
}

# --------------------------------------------------------------------------
# In-cluster probes — connectivity/DNS is always tested from inside the
# cluster, never from the host (independent of podman/host routing).
# --------------------------------------------------------------------------

# pod_http_get <ns> <pod> <url> [container] — wget inside an existing pod.
pod_http_get() {
    local ns="$1" pod="$2" url="$3" c="${4:-}"
    local args=()
    [[ -n "$c" ]] && args=(-c "$c")
    k exec "$pod" -n "$ns" "${args[@]}" -- wget -qO- -T 3 "$url"
}

# Probes retry — short-lived flakes happen when a target is mid-restart
# (e.g. an ingress controller right after a reload). PROBE_ATTEMPTS=1
# disables retrying.
PROBE_ATTEMPTS="${PROBE_ATTEMPTS:-3}"

# probe_http <url> [header ...] — ephemeral busybox pod in 'default';
# each header arg becomes a wget --header. Prints the response body.
# Retries up to $PROBE_ATTEMPTS times, 5s apart. Pod stderr is suppressed —
# kubectl run streams it inline and busybox wget's TLS note would corrupt
# the captured body.
probe_http() {
    local url="$1"; shift
    local pod="probe-http-$RANDOM" args=(-qO- -T 5) h attempt
    for h in "$@"; do args+=(--header "$h"); done
    args+=("$url")
    for (( attempt=1; attempt<=PROBE_ATTEMPTS; attempt++ )); do
        if k run "$pod-$attempt" -n default --image=busybox:1.36 --rm -i \
                --restart=Never --quiet \
                -- sh -c 'wget "$@" 2>/dev/null' wget "${args[@]}"; then
            return 0
        fi
        k delete pod "$pod-$attempt" -n default --ignore-not-found \
            --wait=false >/dev/null 2>&1 || true
        (( attempt < PROBE_ATTEMPTS )) && sleep 5
    done
    return 1
}

# probe_dns <name> — same ephemeral-pod pattern running nslookup,
# with the same retry policy.
probe_dns() {
    local name="$1" pod="probe-dns-$RANDOM" attempt
    for (( attempt=1; attempt<=PROBE_ATTEMPTS; attempt++ )); do
        if k run "$pod-$attempt" -n default --image=busybox:1.36 --rm -i \
                --restart=Never --quiet -- nslookup "$name"; then
            return 0
        fi
        k delete pod "$pod-$attempt" -n default --ignore-not-found \
            --wait=false >/dev/null 2>&1 || true
        (( attempt < PROBE_ATTEMPTS )) && sleep 5
    done
    return 1
}

kube_dns_ip() {
    k -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}'
}

# harden_ingress_nginx — patch the ingress-nginx addon for podman-driver
# quirks (reuseport blackholes ~half of connections after a reload; the
# addon's 1s probes kill the controller under memory stalls). Idempotent:
# patches are applied only when values differ; the rollout restart runs
# only when the ConfigMap alone changed (the deploy patch rolls itself).
harden_ingress_nginx() {
    local changed=0
    if [[ "$(k -n ingress-nginx get cm ingress-nginx-controller \
            -o jsonpath='{.data.reuse-port}' 2>/dev/null)" != "false" ]]; then
        info "disabling nginx reuse-port (environment quirk — see AGENTS.md)"
        k -n ingress-nginx patch cm ingress-nginx-controller --type=merge \
            -p '{"data":{"reuse-port":"false"}}' >/dev/null
        changed=1
    fi
    if [[ "$(k -n ingress-nginx get deploy ingress-nginx-controller \
            -o jsonpath='{.spec.template.spec.containers[?(@.name=="controller")].livenessProbe.timeoutSeconds}' \
            2>/dev/null)" != "5" ]]; then
        info "relaxing ingress-nginx probe timeouts (environment quirk — see AGENTS.md)"
        k -n ingress-nginx patch deploy ingress-nginx-controller \
            --type=strategic \
            -p '{"spec":{"template":{"spec":{"containers":[{"name":"controller","livenessProbe":{"timeoutSeconds":5,"failureThreshold":5},"readinessProbe":{"timeoutSeconds":5,"failureThreshold":5}}]}}}}' \
            >/dev/null
        changed=0   # the deploy patch rolls pods itself
    fi
    if (( changed )); then
        k -n ingress-nginx rollout restart \
            deploy/ingress-nginx-controller >/dev/null
    fi
    wait_rollout ingress-nginx ingress-nginx-controller 240s
}

# ensure_node_etcd_tools — the node has no etcdctl/etcdutl of its own
# (only inside the etcd container, which is gone mid-restore); copy the
# host binaries in via `minikube cp` when missing or on version drift.
ensure_node_etcd_tools() {
    local cp bin host_ver node_ver
    cp="$(control_plane_node)"
    for bin in etcdctl etcdutl; do
        host_ver="$("$bin" version 2>/dev/null | head -1)"
        node_ver="$(node_ssh "$cp" \
            "sudo /usr/local/bin/$bin version 2>/dev/null | head -1" \
            2>/dev/null | tr -d '\r' || true)"
        if [[ "$node_ver" != "$host_ver" || -z "$node_ver" ]]; then
            info "copying $bin into the node ($host_ver)"
            mk cp "$(command -v "$bin")" "/tmp/$bin" >/dev/null
            node_ssh "$cp" "sudo mv /tmp/$bin /usr/local/bin/$bin \
                && sudo chmod +x /usr/local/bin/$bin" >/dev/null
        fi
    done
}

# --------------------------------------------------------------------------
# Object backup/restore (e.g. the coredns ConfigMap a lab mutates)
# --------------------------------------------------------------------------

# backup_object <kind> <name> <ns> <file> — store as JSON minus server fields.
# Pass an empty <ns> for cluster-scoped kinds (storageclass, clusterrole, …).
backup_object() {
    local kind="$1" name="$2" ns="$3" file="$4"
    mkdir -p "$(dirname "$file")"
    local nsargs=()
    [[ -n "$ns" ]] && nsargs=(-n "$ns")
    k get "$kind" "$name" "${nsargs[@]}" -o json \
        | jq 'del(.metadata.resourceVersion, .metadata.uid,
                 .metadata.creationTimestamp, .metadata.managedFields,
                 .metadata.generation, .status)' > "$file"
}

# restore_object <file> — put a backup back (replace, fall back to apply).
restore_object() {
    local file="$1"
    [[ -f "$file" ]] || { warn "restore_object: no such file: $file"; return 1; }
    k replace -f "$file" >/dev/null 2>&1 || k apply -f "$file" >/dev/null
}

# --------------------------------------------------------------------------
# Progress tracking
# --------------------------------------------------------------------------
mark_lab_complete() {
    [[ -n "${LAB_ID:-}" ]] || return 0
    mkdir -p "$PROGRESS_DIR"
    date -Iseconds > "$PROGRESS_DIR/$LAB_ID"
}

lab_is_complete() {
    [[ -f "$PROGRESS_DIR/$1" ]]
}
