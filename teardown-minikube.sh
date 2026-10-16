#!/usr/bin/env bash
# teardown-minikube.sh — remove the 'cka-labs' cluster so 'make setup'
# starts fresh. Scoped to $MINIKUBE_PROFILE only: other minikube profiles
# and unrelated driver networks are never touched.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

lab_banner() { :; }   # top-level script: silence per-lab banner

OUT_ROOT="${CKA_OUT:-$HOME/cka-labs-out}"

usage() {
    cat <<EOF
usage: $(basename "$0") [--all]

Deletes the '$MINIKUBE_PROFILE' minikube profile created by
setup-minikube.sh: the cluster itself, stray kubeconfig entries, a
leftover driver network of the same name, and .state/ backups (which
reference the deleted cluster anyway).

  --all   also wipe learner state: $PROGRESS_DIR and the lab output
          dirs ($OUT_ROOT/NN) — refuses if CKA_OUT points at /, ~ or
          the repo itself

Afterwards 'make setup' bootstraps a clean cluster.
EOF
}

wipe_all=0
for arg in "$@"; do
    case "$arg" in
        --all)      wipe_all=1 ;;
        -h|--help)  usage; exit 0 ;;
        *)          usage >&2; die "unknown flag: $arg" ;;
    esac
done

require_command jq "install via your distro"

# same rootless/rootful decision setup made (minikube stores it in the
# profile config too); never die here when no driver is found — the
# profile deletion below must still be attempted.
apply_podman_mode || true

if (( wipe_all )); then
    case "$OUT_ROOT" in
        ""|"/"|"$HOME"|"$REPO_ROOT")
            die "refusing --all: CKA_OUT/OUT_ROOT resolves to '$OUT_ROOT'" ;;
    esac
fi

info "tearing down minikube profile '$MINIKUBE_PROFILE'"

# --- delete the cluster ------------------------------------------------------
if ! command -v minikube >/dev/null 2>&1; then
    warn "minikube not found on PATH — skipping cluster deletion"
elif profile_exists; then
    info "deleting cluster '$MINIKUBE_PROFILE'"
    mk delete   # also removes the profile's kubeconfig context/cluster/user
else
    info "profile '$MINIKUBE_PROFILE' does not exist — nothing to delete"
fi

# --- stray kubeconfig entries ------------------------------------------------
# minikube delete normally cleans these; remove leftovers from a partial
# create/delete so a fresh 'make setup' never inherits stale entries.
kc_has() {  # kc_has <contexts|clusters|users> <name>
    [[ -n "$(kubectl config view \
        -o "jsonpath={.$1[?(@.name=='$2')].name}" 2>/dev/null)" ]]
}
if command -v kubectl >/dev/null 2>&1; then
    for entry in "contexts delete-context" "clusters delete-cluster" \
            "users delete-user"; do
        read -r section delcmd <<<"$entry"
        if kc_has "$section" "$MINIKUBE_PROFILE"; then
            info "removing leftover kubeconfig ${section%s} \
'$MINIKUBE_PROFILE'"
            kubectl config "$delcmd" "$MINIKUBE_PROFILE" >/dev/null || true
        fi
    done
fi

# --- leftover driver network --------------------------------------------------
# setup-minikube.sh pre-creates a podman network named after the profile on
# hosts without aardvark-dns, and the docker driver creates one too —
# minikube delete does not always remove a network it did not create.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 \
        && docker network inspect "$MINIKUBE_PROFILE" >/dev/null 2>&1; then
    info "removing leftover docker network '$MINIKUBE_PROFILE'"
    docker network rm "$MINIKUBE_PROFILE" >/dev/null 2>&1 \
        || warn "could not remove docker network '$MINIKUBE_PROFILE'"
fi
if command -v podman >/dev/null 2>&1 \
        && { sudo -n podman info >/dev/null 2>&1 \
             || podman info >/dev/null 2>&1; }; then
    pc="$(podman_cmd)"
    if $pc network exists "$MINIKUBE_PROFILE" 2>/dev/null; then
        info "removing leftover podman network '$MINIKUBE_PROFILE'"
        $pc network rm "$MINIKUBE_PROFILE" >/dev/null 2>&1 \
            || warn "could not remove podman network '$MINIKUBE_PROFILE'"
    fi
fi

# --- repo-local state ----------------------------------------------------------
# .state/ holds backups of objects from the deleted cluster — useless now.
rm_rf() {   # refuse to delete anything outside the repo or $HOME
    local d="$1"
    [[ -d "$d" ]] || return 0
    [[ "$d" == "$REPO_ROOT/"* || "$d" == "$HOME/"* ]] \
        || die "refusing to remove unexpected path: $d"
    info "removing $d"
    rm -rf "$d"
}
rm_rf "$STATE_DIR"

# --all removes only the per-lab output dirs ($OUT_ROOT/NN), never
# $OUT_ROOT itself unless it is left empty — CKA_OUT could point anywhere.
wipe_out_dirs() {
    [[ -d "$OUT_ROOT" ]] || return 0
    local d removed=0
    for d in "$OUT_ROOT"/[0-9][0-9]; do
        [[ -d "$d" ]] || continue
        info "removing $d"
        rm -rf "$d"
        removed=1
    done
    rmdir "$OUT_ROOT" 2>/dev/null || true   # drops it only if now empty
    (( removed )) || info "nothing to remove under $OUT_ROOT"
}

if (( wipe_all )); then
    rm_rf "$PROGRESS_DIR"
    wipe_out_dirs
fi

# --- summary -------------------------------------------------------------------
echo
info "teardown complete"
if (( wipe_all )); then
    info "run 'make progress' to regenerate PROGRESS.md"
else
    info "learner state kept ($PROGRESS_DIR, $OUT_ROOT)"
    info "  rerun with --all to wipe those too"
fi
info "run 'make setup' to bootstrap a fresh cluster"
