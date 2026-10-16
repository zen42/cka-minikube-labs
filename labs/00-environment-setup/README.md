# Lab 00 – Environment Setup

**Domain:** All (environment foundation) · **Builds on:** none

Get your machine exam-ready: install the CLI tools, boot the shared minikube
cluster, configure your kubectl context, and take a first look inside the
node. Every later lab assumes this one is done.

## Objectives

- Install and verify `kubectl`, `helm`, `kustomize`, `etcdctl` at the pinned
  versions (`versions.env`).
- Start a minikube cluster (`cka-labs` profile, Kubernetes v1.34, containerd,
  Calico CNI, metrics-server + ingress addons).
- Configure your kubectl context and default namespace.
- Set up the `k` alias and bash completion like the real exam environment.
- Explore the node with `minikube ssh` and `crictl`.

## Environment

- **Cluster:** minikube profile `cka-labs` (context `cka-labs`).
- **Namespaces:** `playground` (you create it in task 5).
- **Output dir:** `~/cka-labs-out/00/`
- **Start here:** finish task 1 (tools) first, then `make lab-00` — it
  runs `check-env.sh` then `setup.sh`, which creates the cluster on first
  run by invoking `./setup-minikube.sh` (this takes a few minutes).

## Tasks

1. Run `scripts/check-prereqs.sh`. If anything is MISSING, run
   `scripts/install-tools.sh` (or `make tools`) and re-check until green.
2. Confirm the cluster is up: `kubectl get nodes` shows one node in
   `Ready` state. (`make lab-00` already ran `./setup-minikube.sh` for
   you; re-running `./setup-minikube.sh` or `make setup` is safe.)
3. Make `cka-labs` your current kubectl context:
   `kubectl config use-context cka-labs`
4. Set up the exam-style alias and completion for this shell session:

   ```bash
   alias k=kubectl
   source <(kubectl completion bash)
   complete -o default -F __start_kubectl k
   ```

5. Create a namespace `playground` labeled `env=learning`:
   `kubectl create namespace playground` then
   `kubectl label namespace playground env=learning`
6. Make `playground` the default namespace of your current context:
   `kubectl config set-context --current --namespace=playground`
7. Save `kubectl get nodes -o yaml` to `~/cka-labs-out/00/nodes.yaml` and the
   output of `kubectl cluster-info` to `~/cka-labs-out/00/cluster-info.txt`.
8. Look inside the node with `minikube -p cka-labs ssh`, then run
   `sudo crictl ps` and `ls /etc/kubernetes/manifests`. Save the container
   list to `~/cka-labs-out/00/crictl-ps.txt` without entering the node:

   ```bash
   minikube -p cka-labs ssh -- sudo crictl ps > ~/cka-labs-out/00/crictl-ps.txt
   ```

## Verify

```bash
make verify-00     # from the repo root — or ./verify.sh in this directory
```

Checks: tools at pinned versions, profile running, node Ready, server v1.34,
calico/metrics-server/ingress up, context `cka-labs` with default namespace
`playground`, and the three output files.

## Clean up

```bash
make teardown-00   # from the repo root — or ./teardown.sh in this directory
```

Removes the `playground` namespace, resets the context namespace, and clears
`~/cka-labs-out/00/`. The cluster keeps running — every later lab needs it.

## Docs

- https://kubernetes.io/docs/tasks/tools/
- https://kubernetes.io/docs/reference/kubectl/quick-reference/
- https://kubernetes.io/docs/reference/kubectl/cheatsheet/
