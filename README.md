# CKA Minikube Labs

A progressive, self-contained set of hands-on practice labs for the
**Certified Kubernetes Administrator (CKA)** exam, running on a single shared
[minikube](https://minikube.sigs.k8s.io/) cluster (Kubernetes **v1.34**, containerd,
Calico CNI so NetworkPolicies are enforced).

Each lab is a directory under `labs/` with exam-style tasks, a reference
solution, and scripts that set up, solve, verify, and reset the lab state.

## Requirements

| Requirement | Notes |
|-------------|-------|
| Linux (x86_64 or arm64) | tested on Debian 13 |
| bash >= 4.4, make, jq, curl, git | from your distro |
| minikube | `minikube version` >= 1.39 recommended |
| A container driver | docker, or podman (rootless or `sudo -n podman`) |
| ~4 CPU / 8 GB RAM / 20 GB disk | multi-node labs add worker nodes on demand |
| `fs.inotify.max_user_instances` >= 1024 | multi-node labs 14/20/23; `make prereqs` tells you how |
| kubectl, helm, kustomize, etcdctl | installed for you by `make tools` |

## Quick start

```bash
make prereqs          # what's missing?
make tools            # install pinned kubectl/helm/kustomize/etcdctl into ~/.local/bin
make setup            # create the 'cka-labs' minikube cluster (takes a few minutes)
make lab-00           # run environment checks + setup for lab 00, then read labs/00-*/README.md
```

## Lab index

| # | Lab | CKA domain | Status |
|---|-----|------------|--------|
| 00 | Environment Setup | — | available |
| 01 | kubectl Basics | All (foundation) | available |
| 02 | Pod Management | Workloads & Scheduling | available |
| 03 | ConfigMaps & Secrets | Workloads & Scheduling | available |
| 04 | Deployments & Rollouts | Workloads & Scheduling | available |
| 05 | Jobs & CronJobs | Workloads & Scheduling | available |
| 06 | Services & Endpoints | Services & Networking | available |
| 07 | Network Policies | Services & Networking | available |
| 08 | Ingress & Gateway API | Services & Networking | available |
| 09 | DNS & CoreDNS | Services & Networking | available |
| 10 | RBAC for Users/Groups | Cluster Architecture | available |
| 11 | Service Accounts | Cluster Architecture | available |
| 12 | Persistent Volumes & Claims | Storage | available |
| 13 | StorageClasses & Dynamic Provisioning | Storage | available |
| 14 | Scheduling: Selectors, Affinity, Taints | Workloads & Scheduling | available (multi-node) * |
| 15 | HPA & Resource Limits | Workloads & Scheduling | available |
| 16 | Helm | Cluster Architecture | available |
| 17 | Kustomize | Cluster Architecture | available |
| 18 | CRDs & Operators | Cluster Architecture | available |
| 19 | Extension Interfaces (CNI/CSI/CRI) | Cluster Architecture | available |
| 20 | Cluster Lifecycle with kubeadm | Cluster Architecture | available (multi-node) * |
| 21 | etcd Backup & Restore | Cluster Architecture | available |
| 22 | Troubleshooting Pods | Troubleshooting | available |
| 23 | Troubleshooting Nodes | Troubleshooting | available (multi-node) * |
| 24 | Troubleshooting Services & Networking | Troubleshooting | available |
| 25 | Troubleshooting Control Plane | Troubleshooting | available |
| 26 | Final Review | All | available |

\* Labs 14, 20 and 23 add two worker nodes via `minikube node add` on
first setup (~2 extra GB RAM) and need
`fs.inotify.max_user_instances >= 1024` — `make prereqs` prints the
one-line sysctl fix if it's too low. Adding nodes also makes minikube
disable the storage-provisioner/ingress addons; lab setups re-enable
them automatically.

See `docs/curriculum-mapping.md` for the mapping to CNCF CKA curriculum topics.

## How a lab works

Every `labs/NN-slug/` directory contains exactly:

| File | Purpose |
|------|---------|
| `README.md` | the lab: objectives, environment, numbered tasks |
| `SOLUTION.md` | reference commands per task |
| `check-env.sh` | readiness check (tools, cluster, prerequisites) — never mutates |
| `setup.sh` | idempotent seeding of namespaces / broken resources |
| `solve.sh` | non-interactive reference solution (kept in sync with SOLUTION.md) |
| `verify.sh` | one check per task; exits 0 iff all pass |
| `teardown.sh` | removes everything the lab created; never deletes the cluster |
| `manifests/` | YAML used by setup/verify |

Workflow:

```bash
make lab-NN       # check-env + setup, then read labs/NN-*/README.md and do the tasks
make verify-NN    # did I finish? (prints PASS/FAIL per check)
make teardown-NN  # clean the lab's resources
make test-NN      # machine-test the whole lab end-to-end (setup->solve->verify->teardown)
```

## Conventions

- **One shared cluster**: minikube profile `cka-labs` (kubectl context of the
  same name). Lab scripts always pin `--context cka-labs`; your current
  context doesn't matter to them.
- **Namespaces**: every lab works in its own short-named namespace(s), all
  labeled `cka-lab=NN` so `make clean-all` can wipe them.
- **Output files**: tasks that say "save X to a file" write under
  `~/cka-labs-out/NN/` (override the root with `CKA_OUT`).
- **Progress**: `verify.sh` records completion markers in `.progress/`;
  `make progress` regenerates `PROGRESS.md`.
- In the exam (and optionally here) set up:

  ```bash
  alias k=kubectl
  source <(kubectl completion bash)
  complete -o default -F __start_kubectl k
  ```

## Troubleshooting

- **podman driver**: rootless podman needs `newuidmap`/`fuse-overlayfs`. If
  only rootful podman works (e.g. `sudo -n podman info` succeeds), minikube
  handles the sudo calls itself — just ensure your sudoers rule is
  `NOPASSWD` for podman. `make setup` auto-detects a working driver.
- **podman DNS broken inside the node?** If the host lacks `aardvark-dns`,
  podman networks give containers a dead resolver (`ErrImagePull` on calico/
  coredns etc). `make setup` detects this and pre-creates the `cka-labs`
  podman network with `--disable-dns` so the node uses the host resolver.
- **containers can't reach the network (ping works, TCP/UDP dead)?** UFW's
  `FORWARD` chain policy is `DROP` and explicitly allows ICMP only — very
  misleading. `make setup` detects this (`check_container_egress`) and
  prints the one-time durable fix; it never touches your firewall:
  1. In `/etc/ufw/before.rules`, inside `*filter` before `COMMIT`, add:
     `-A ufw-before-forward -i podman+ -j ACCEPT` and
     `-A ufw-before-forward -o podman+ -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT`
  2. `sudo ufw reload`
  (Broader alternative: `DEFAULT_FORWARD_POLICY="ACCEPT"` in
  `/etc/default/ufw`. The durable fix for the missing-DNS quirk is
  `sudo apt install aardvark-dns`.)
- **Wrong kubectl context?** Lab scripts don't care — they always use
  `--context cka-labs`. For your own exploring run
  `kubectl config use-context cka-labs`.
- **Cluster wedged?** `make reset-cluster` deletes and recreates only the
  `cka-labs` profile; `make teardown-cluster` deletes it without recreating
  (`./teardown-minikube.sh --all` also wipes `.progress/` and
  `~/cka-labs-out` for a completely fresh start). `minikube delete -p
  cka-labs` never touches other profiles — the `-p` flag is always explicit
  in this repo.
- **Partial lab state?** `make teardown-NN`, or `make clean-all` to wipe all
  lab namespaces (`kubectl delete ns -l cka-lab`).

## License

Apache License 2.0 — see `LICENSE`.
