# AGENTS.md — project conventions

Bash-only, Linux-only CKA practice labs on one shared minikube cluster.

## Non-negotiables

- All scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, executable bit,
  `bash -n` clean, shellcheck clean when shellcheck is installed.
- Lab scripts source helpers via:

  ```bash
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"
  ```

  Top-level scripts use `$(dirname "${BASH_SOURCE[0]}")/common.sh`.
- Never touch minikube profiles other than `$MINIKUBE_PROFILE` (`cka-labs`).
  A user profile may coexist — always pass `-p cka-labs`.
- Lab code never depends on the user's current kubectl context: always use
  `k` (which pins `--context cka-labs`). Same for helm: `h` pins
  `--kube-context cka-labs`. Learner-facing README text uses plain
  `kubectl`/`helm`.
- Colors only when stdout is a TTY (helpers already handle this). No emojis.
- Doc links in lab READMEs only to the sites allowed in the real exam:
  kubernetes.io/docs, kubernetes.io/blog, github.com/kubernetes,
  helm.sh/docs, gateway-api.sigs.k8s.io.

## The 7-file lab contract

Every `labs/NN-slug/` contains exactly:
`README.md`, `SOLUTION.md`, `check-env.sh`, `setup.sh`, `solve.sh`,
`verify.sh`, `teardown.sh`, `manifests/` (`.gitkeep` if empty).

| Script | Contract |
|--------|----------|
| `check-env.sh` | readiness only; MUST NOT mutate. `require_command`, `require_cluster`, `require_nodes`, `require_addon`. Ends by printing a READY line. (Lab 00 is the exception: no cluster required.) |
| `setup.sh` | idempotent; re-running resets the lab to a clean start state. `ensure_namespace` (applies `cka-lab=NN`) for seeded ns, seeds broken/pre-existing resources, creates `$OUT_DIR`. **If a task asks the learner to CREATE a namespace, do NOT create it here — only `delete_namespace_if_exists` any stale one.** |
| `solve.sh` | non-interactive reference solution, re-runnable (apply patterns, `--ignore-not-found`, `|| true` only where idempotency needs it). Must mirror SOLUTION.md command-for-command, in order. |
| `verify.sh` | one `check*` call per task, then `finish_checks`. Read-only (ephemeral probe pods allowed if cleaned up). NEVER abort on first failure. |
| `teardown.sh` | idempotent; deletes namespaces by name, cluster-scoped objects, node labels/taints, `$OUT_DIR`, kubeconfig changes. NEVER deletes the cluster. |

`SOLUTION.md` structure: `# Lab NN – Solution` then `### Task N` blocks with
exact commands + a one-line "why" where non-obvious.

`README.md` structure: `# Lab NN – Title` · `**Domain:** X (w%) · **Builds on:**
Lab MM` · `## Objectives` · `## Environment` · `## Tasks` (numbered,
exam-style imperative) · `## Verify` · `## Clean up` · `## Docs`.

## Assertion API (verify.sh)

```
check "<desc>" <cmd...>                       # pass iff cmd exits 0
check_eq "<desc>" "<actual>" "<expected>"
check_match "<desc>" "<actual>" "<regex>"
check_file_contains "<desc>" <file> <regex>
check_resource "<desc>" <kind> <name> [-n ns]
check_absent    "<desc>" <kind> <name> [-n ns]
check_jsonpath  "<desc>" <kind>/<name> "{.jp}" "<expected>" [-n ns]
                # actual is trimmed of leading/trailing whitespace only —
                # expected values may contain spaces (e.g. '*/5 * * * *')
check_fails     "<desc>" <cmd...>             # pass iff cmd exits NON-zero
finish_checks                                 # prints tally, marks progress, exits
```

## In-cluster probes & object backup

Connectivity is ALWAYS tested from inside the cluster (podman host routing is
unreliable). All "server" pods use the busybox httpd trick so any pod can
both serve and probe:

```sh
busybox:1.36  →  sh -c 'mkdir -p /www && echo "<token>" > /www/index.html \
                 && httpd -f -p 80 -h /www'
```

```
pod_http_get <ns> <pod> <url> [container]   # wget -qO- inside an existing pod
probe_http <url> [header ...]              # ephemeral busybox pod; prints body
probe_dns <name>                           # ephemeral busybox pod; nslookup
# both retry up to PROBE_ATTEMPTS (default 3) times, 5s apart
kube_dns_ip                                # ClusterIP of svc kube-dns
backup_object <kind> <name> <ns> <file>    # JSON minus server fields -> STATE_DIR
                                         # empty <ns> = cluster-scoped kind
restore_object <file>                      # kubectl replace (apply fallback)
```

`STATE_DIR` = `$REPO_ROOT/.state` (gitignored) — store backups of cluster
objects a lab mutates there so teardown can restore them. Never overwrite an
existing backup in setup.sh (an interrupted lab may have left mutations).
Teardown deletes the backup once the restore is confirmed — a stale backup
could restore an outdated object after a cluster upgrade.

Gotcha: shell functions (`k`, `probe_http`, `probe_dns`, `pod_http_get`,
`kube_dns_ip`) do NOT exist inside `bash -c "…"` — inside `bash -c` call
`kubectl --context "$KUBE_CONTEXT"` directly, or compute values in the main
shell and pass them to `check`/`check_eq`. Command substitution
`$(probe_http …)` in the same shell is fine.

## Key helpers (common.sh)

`k`, `mk`, `h`, `node_ssh <node> <cmd>`, `control_plane_node`,
`minikube_node_count`, `ensure_minikube_nodes <n>`,
`require_command`, `require_cluster`, `require_addon`, `require_nodes`,
`ensure_namespace`, `delete_namespace_if_exists`, `delete_if_exists`,
`wait_for <desc> <s> <cmd>`, `wait_rollout`, `wait_pod_ready`, `pod_phase`,
`all_nodes_ready`, `deploy_available`, `mark_lab_complete`, `lab_is_complete`,
`harden_ingress_nginx`, `ensure_node_etcd_tools`.

Globals: `REPO_ROOT`, `LAB_DIR`, `LAB_ID`, `LAB_SLUG`, `LAB_NAME`,
`OUT_DIR` (`${CKA_OUT:-~/cka-labs-out}/NN`), `KUBE_CONTEXT`, `PROGRESS_DIR`.

## Environment quirks

- Driver is auto-detected: docker, then podman. On this host only rootful
  podman works (`sudo -n podman` is passwordless); minikube wraps podman
  calls in sudo itself.
- CNI is **Calico** (`MINIKUBE_CNI` in versions.env) — the default
  kindnet/bridge CNI does NOT enforce NetworkPolicy.
- All versions are pinned in `versions.env` and env-overridable
  (`: "${VAR:=default}"`). Tools are installed to `~/.local/bin`
  (`TOOLS_DIR` overridable) by `scripts/install-tools.sh`.
- Inside the node: `crictl` at /usr/local/bin, kubeadm/kubelet under
  `/var/lib/minikube/binaries/<k8s-ver>/`, static manifests at
  `/etc/kubernetes/manifests`, etcd data `/var/lib/minikube/etcd`, etcd
  certs `/var/lib/minikube/certs/etcd`. Host has no crictl/etcdctl access to
  the cluster's etcd — use `minikube -p cka-labs ssh`.
- **aardvark-dns is not installed on this host** → podman `dns_enabled`
  networks hand containers a dead resolver (gateway IP, nothing listening).
  `setup-minikube.sh` prints the durable fix (`sudo apt install
  aardvark-dns`) and falls back to pre-creating the `cka-labs` network with
  `--disable-dns` (minikube reuses an existing network of the same name).
- **UFW is active with `FORWARD` policy `DROP`** and ICMP explicitly
  allowed — so container ping works while TCP/UDP die.
  `setup-minikube.sh` only DETECTS this (`check_container_egress`,
  overridable probe via `CKA_EGRESS_PROBE_URL`) and INSTRUCTS the user
  (exact `/etc/ufw/before.rules` lines + `sudo ufw reload`); it never runs a
  privileged container or edits the firewall. Do not reintroduce an
  auto-fix.
- **The 4GiB node memory ceiling throttles under load** — the minikube
  container's cgroup `memory.max` stalls every allocator when hit
  (check `/sys/fs/cgroup/memory.events` inside the node: `max` events),
  which froze nginx workers AND liveness probes. `MINIKUBE_MEMORY` is now
  8192; `setup-minikube.sh` also live-raises a running node's limit via
  `docker/podman update --memory` when it is below the pin.
- **ingress-nginx `reuseport` wedges under this driver** — after every
  config reload, drained workers keep their per-worker listen sockets and
  the kernel keeps hashing new connections onto them: roughly half of all
  requests connect then hang forever. Lab 08 setup patches
  `reuse-port: "false"` into the `ingress-nginx-controller` ConfigMap and
  restarts the controller. reuseport alone is not sufficient: the addon's
  liveness/readiness probes use `timeoutSeconds: 1`, so a reload under a
  memory stall fails liveness and the kubelet kills the controller mid-lab
  — lab 08 setup also patches both probes to `timeoutSeconds: 5`,
  `failureThreshold: 5` on the controller Deployment. Also note: a
  TLS-configured Ingress 308-redirects HTTP to `https://<host>` — probe
  those hosts over `https://` on the controller service (busybox wget does
  not verify certs).
- **Probes retry.** `probe_http`/`probe_dns` retry up to
  `PROBE_ATTEMPTS` (default 3) times, 5s apart — in-cluster targets are
  often mid-restart when verify runs.
- **`fs.inotify.max_user_instances=128` is too small for multi-node** —
  every kubelet/cAdvisor/containerd consumes instances from a shared
  per-UID budget, so `minikube node add` fails at join time
  ("inotify_init: too many open files", worker kubelet never healthy).
  `ensure_minikube_nodes` detects a low limit and prints the fix
  (`sudo sysctl -w fs.inotify.max_user_instances=8192`); it never mutates
  the host itself.
- **`minikube node add` disables cluster addons** — storage-provisioner,
  default-storageclass, ingress (and metrics-server) all get flipped to
  "disabled" in the addon registry (and their deployments removed) when
  the cluster goes multi-node, because hostpath provisioning is
  node-local. `ensure_minikube_nodes` re-enables all four and waits for
  their rollouts — also when the node count is already satisfied, so
  hand-added nodes are covered too.
- **busybox `nslookup` skips the search list for dotted names** — it
  treats `api.dns-other` as already fully-qualified (NXDOMAIN) while
  dotless names like `web` expand fine. Prove dotted short names through
  the libc resolver (`wget -qO- http://api.dns-other/`), not nslookup.
- **`node_ssh` output is CRLF-translated** — the ssh channel rewrites
  `\n` to `\r\n`, so anything captured through it lands on disk with
  Windows line endings. Pipe captures through `tr -d '\r'` whenever the
  bytes will be compared or restored (e.g. static-manifest backups in
  labs 21/25); diagnostic `$OUT_DIR` files can ignore it — greps still
  match.
- **Completed Jobs carry TWO conditions** — on v1.31+ a finished Job has
  `SuccessCriteriaMet=True` *and* `Complete=True`, so
  `conditions[0].type` is never `Complete`. Gate on
  `kubectl wait --for=condition=complete` or grep
  `conditions[*].type`; never index `[0]`.

## Adding a lab — checklist

1. `mkdir labs/NN-slug/manifests` (+ `.gitkeep` if unused).
2. Write the 6 files + README/SOLUTION per contract; chmod +x the 5 scripts.
3. Namespaces are short topical words; tasks reference exact names/images.
4. `bash -n` every script; `make test-NN` must pass end-to-end.
5. Negative path: `setup.sh` then `verify.sh` (no solve) must exit 1 and
   list the failed tasks.
6. Add the lab to the index table in the top-level README.
