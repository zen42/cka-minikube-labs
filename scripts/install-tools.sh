#!/usr/bin/env bash
# install-tools.sh — install the pinned CLI tools into ${TOOLS_DIR:-~/.local/bin}
# No sudo. Idempotent: skips tools already at the pinned version.
# Usage: scripts/install-tools.sh [--force]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

TOOLS_DIR="${TOOLS_DIR:-$HOME/.local/bin}"
mkdir -p "$TOOLS_DIR"

case "$(uname -m)" in
    x86_64)  ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

download() {  # download <url> <dest>
    curl -fsSL --retry 3 -o "$2" "$1" || die "download failed: $1"
}

verify_sha() {  # verify_sha <file> <expected-hex>
    local got
    got="$(sha256sum "$1" | awk '{print $1}')"
    [[ "$got" == "$2" ]] || die "checksum mismatch for $1 (got $got, want $2)"
}

# current <tool> -> prints installed version tag or empty string
current() {
    case "$1" in
        kubectl)   kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' ;;
        helm)      helm version --short 2>/dev/null | cut -d+ -f1 ;;
        kustomize) kustomize version 2>/dev/null | awk '{print $1}' ;;
        etcdctl)   etcdctl version 2>/dev/null | awk -F': ' '/^etcdctl version/ {print "v"$2}' ;;
    esac
}

install_kubectl() {
    local url="https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/${ARCH}/kubectl"
    download "$url" "$TMP/kubectl"
    download "${url}.sha256" "$TMP/kubectl.sha256"
    verify_sha "$TMP/kubectl" "$(cat "$TMP/kubectl.sha256")"
    install -m 0755 "$TMP/kubectl" "$TOOLS_DIR/kubectl"
    info "kubectl $KUBERNETES_VERSION installed"
}

install_helm() {
    local base="helm-${HELM_VERSION}-linux-${ARCH}"
    download "https://get.helm.sh/${base}.tar.gz" "$TMP/helm.tar.gz"
    download "https://get.helm.sh/${base}.tar.gz.sha256sum" "$TMP/helm.sha256sum"
    # file may be '<hex>  <name>' or just '<hex>'
    verify_sha "$TMP/helm.tar.gz" "$(awk '{print $1}' "$TMP/helm.sha256sum")"
    tar -xzf "$TMP/helm.tar.gz" -C "$TMP"
    install -m 0755 "$TMP/linux-${ARCH}/helm" "$TOOLS_DIR/helm"
    info "helm $HELM_VERSION installed"
}

install_kustomize() {
    local base="kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}"
    local repo="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}"
    download "${repo}/${base}.tar.gz" "$TMP/kustomize.tar.gz"
    download "${repo}/checksums.txt" "$TMP/kustomize.checksums"
    local want
    want="$(awk -v f="${base}.tar.gz" '$2 == f {print $1}' "$TMP/kustomize.checksums")"
    [[ -n "$want" ]] || die "no checksum for ${base}.tar.gz in checksums.txt"
    verify_sha "$TMP/kustomize.tar.gz" "$want"
    tar -xzf "$TMP/kustomize.tar.gz" -C "$TMP" kustomize
    install -m 0755 "$TMP/kustomize" "$TOOLS_DIR/kustomize"
    info "kustomize $KUSTOMIZE_VERSION installed"
}

install_etcdctl() {
    local base="etcd-${ETCD_VERSION}-linux-${ARCH}"
    local repo="https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}"
    download "${repo}/${base}.tar.gz" "$TMP/etcd.tar.gz"
    download "${repo}/SHA256SUMS" "$TMP/SHA256SUMS"
    local want
    want="$(awk -v f="${base}.tar.gz" '$2 == f {print $1}' "$TMP/SHA256SUMS")"
    [[ -n "$want" ]] || die "no checksum for ${base}.tar.gz in SHA256SUMS"
    verify_sha "$TMP/etcd.tar.gz" "$want"
    tar -xzf "$TMP/etcd.tar.gz" -C "$TMP" "${base}/etcdctl" "${base}/etcdutl"
    install -m 0755 "$TMP/${base}/etcdctl" "$TOOLS_DIR/etcdctl"
    install -m 0755 "$TMP/${base}/etcdutl" "$TOOLS_DIR/etcdutl"
    info "etcdctl/etcdutl $ETCD_VERSION installed"
}

install_one() {  # install_one <tool> <pinned-version> <installer-fn>
    local tool="$1" want="$2" fn="$3" have
    have="$(current "$tool" || true)"
    if [[ "$have" == "$want" && $FORCE -eq 0 ]]; then
        info "$tool already at $want — skipping (use --force to reinstall)"
        return 0
    fi
    [[ -n "$have" ]] && info "$tool is $have, want $want — reinstalling"
    "$fn"
}

install_one kubectl   "$KUBERNETES_VERSION" install_kubectl
install_one helm      "$HELM_VERSION"       install_helm
install_one kustomize "$KUSTOMIZE_VERSION"  install_kustomize
install_one etcdctl   "$ETCD_VERSION"       install_etcdctl

echo
case ":$PATH:" in
    *":$TOOLS_DIR:"*) ;;
    *)
        warn "$TOOLS_DIR is not on PATH. Add to your shell profile:"
        printf '    export PATH="%s:$PATH"\n' "$TOOLS_DIR"
        ;;
esac

cat <<'EOF'
Recommended exam-style shell setup (the CKA environment pre-defines these):

    alias k=kubectl
    source <(kubectl completion bash)
    complete -o default -F __start_kubectl k
EOF
