#!/usr/bin/env bash
# Lab 16 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

CV="$PODINFO_CHART_VERSION"

# Task 1 — add the podinfo repo, update, list chart versions
h repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null
h repo update >/dev/null
h search repo podinfo --versions > "$OUT_DIR/search.txt"

# Task 2 — dump the chart's default values for the pinned version
h show values podinfo/podinfo --version "$CV" \
    > "$OUT_DIR/values-default.yaml"

# Task 3 — install release 'frontend' (2 replicas), creating ns helm
h install frontend podinfo/podinfo -n helm --create-namespace \
    --version "$CV" --set replicaCount=2 >/dev/null
wait_rollout helm frontend-podinfo 180s

# Task 4 — upgrade: 3 replicas + a UI message (revision 2)
h upgrade frontend podinfo/podinfo -n helm --version "$CV" \
    --set replicaCount=3 --set ui.message="hello cka" >/dev/null
wait_rollout helm frontend-podinfo 180s

# Task 5 — history to file, then roll back to revision 1 (=> revision 3)
h history frontend -n helm > "$OUT_DIR/history.txt"
h rollback frontend 1 -n helm >/dev/null
wait_rollout helm frontend-podinfo 180s

# Task 6 — user-supplied values of the current (rolled-back) revision
h get values frontend -n helm -o yaml > "$OUT_DIR/get-values.yaml"

# Task 7 — scaffold a 'webapp' chart, edit values, lint, render, install
if [[ ! -d "$OUT_DIR/webapp" ]]; then
    ( cd "$OUT_DIR" && h create webapp >/dev/null )
fi
sed -i -e 's/^replicaCount:.*/replicaCount: 2/' \
    -e 's/^  repository:.*/  repository: nginx/' \
    -e 's/^  tag:.*/  tag: "1.27"/' \
    "$OUT_DIR/webapp/values.yaml"
h lint "$OUT_DIR/webapp" >/dev/null
h template webapp "$OUT_DIR/webapp" > "$OUT_DIR/webapp-rendered.yaml"
h upgrade --install webapp "$OUT_DIR/webapp" -n helm >/dev/null
wait_rollout helm webapp 180s

# Task 8 — pull the chart archive locally
h pull podinfo/podinfo --version "$CV" -d "$OUT_DIR" >/dev/null

# Task 9 — uninstall webapp only; frontend must stay
h uninstall webapp -n helm >/dev/null 2>&1 || true

# Task 10 — list all releases as JSON
h list -A -o json > "$OUT_DIR/releases.json"

info "lab 16 solved"
