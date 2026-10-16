# Lab 00 – Solution

### Task 1

```bash
scripts/check-prereqs.sh
scripts/install-tools.sh      # installs pinned versions into ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"   # if it wasn't already on PATH
scripts/check-prereqs.sh      # green
```

### Task 2

```bash
./setup-minikube.sh           # or: make setup
kubectl --context cka-labs get nodes
```

### Task 3

```bash
kubectl config use-context cka-labs
```

### Task 4

```bash
alias k=kubectl
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
```

(Alias/completion only live in the shell you set them in — `solve.sh`
exports the completion script but the alias is a per-shell convenience.)

### Task 5

```bash
kubectl create namespace playground
kubectl label namespace playground env=learning
```

### Task 6

```bash
kubectl config set-context --current --namespace=playground
```

Why: `--current` edits the active context (`cka-labs` after task 3), so plain
`kubectl get pods` defaults to `-n playground`.

### Task 7

```bash
mkdir -p ~/cka-labs-out/00
kubectl get nodes -o yaml > ~/cka-labs-out/00/nodes.yaml
kubectl cluster-info > ~/cka-labs-out/00/cluster-info.txt
```

### Task 8

```bash
minikube -p cka-labs ssh          # explore: sudo crictl ps, ls /etc/kubernetes/manifests
minikube -p cka-labs ssh -- sudo crictl ps > ~/cka-labs-out/00/crictl-ps.txt
```

Why: the minikube node runs the control plane as containers under containerd;
`crictl` talks to the CRI socket (no docker inside). `kube-apiserver` should
appear in the list — proof the control plane is just pods on the node.
