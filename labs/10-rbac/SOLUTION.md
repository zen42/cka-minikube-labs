# Lab 10 – Solution

### Task 1

```bash
kubectl create role pod-reader -n rbac \
    --verb=get,list,watch --resource=pods
```

### Task 2

```bash
kubectl create rolebinding jane-pod-reader -n rbac \
    --role=pod-reader --user=jane
```

### Task 3

```bash
kubectl auth can-i get pods -n rbac --as jane       # yes
kubectl auth can-i create deployments -n rbac --as jane   # no
printf '%s\n%s\n' "$(kubectl auth can-i get pods -n rbac --as jane)" \
    "$(kubectl auth can-i create deployments -n rbac --as jane)" \
    > ~/cka-labs-out/10/can-i.txt
```

### Task 4

```bash
kubectl create clusterrole node-viewer \
    --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding ops-node-viewer \
    --clusterrole=node-viewer --group=ops
kubectl auth can-i list nodes --as=someone --as-group=ops   # yes
```

### Task 5

```bash
kubectl create clusterrole ns-pod-reader \
    --verb=get,list --resource=pods
kubectl create rolebinding jane-ns-pods -n default \
    --clusterrole=ns-pod-reader --user=jane
```

Why: a RoleBinding may reference a ClusterRole — jane gets only the
namespaced permissions (pods), only inside the RoleBinding's namespace
(`default`). `can-i list pods -n kube-system --as jane` stays `no`.

### Task 6

```bash
kubectl delete rolebinding dev-can-view -n rbac
kubectl create rolebinding dev-can-view -n rbac \
    --role=pod-reader --user=dave
```

Why: `roleRef` is immutable; a binding pointing at a missing role grants
nothing, so recreate it pointing at `pod-reader`.

### Task 7

```bash
openssl genrsa -out /tmp/jane.key 2048
openssl req -new -key /tmp/jane.key -out /tmp/jane.csr \
    -subj '/CN=jane/O=developers'
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  signerName: kubernetes.io/kube-apiserver-client
  usages: [client auth]
  expirationSeconds: 86400
  request: $(base64 -w0 /tmp/jane.csr)
EOF
kubectl certificate approve jane
kubectl wait --for=condition=Approved csr/jane --timeout=60s
kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 -d \
    > ~/cka-labs-out/10/jane.crt
```

### Task 8

```bash
JCFG=~/cka-labs-out/10/jane.kubeconfig
SERVER=$(kubectl config view --minify --raw \
    -o jsonpath='{.clusters[0].cluster.server}')
CA_FILE=$(kubectl config view --minify --raw \
    -o jsonpath='{.clusters[0].cluster.certificate-authority}')
if [ -z "$CA_FILE" ]; then
    kubectl config view --minify --raw \
        -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' \
        | base64 -d > ~/cka-labs-out/10/ca.crt
    CA_FILE=~/cka-labs-out/10/ca.crt
fi
kubectl --kubeconfig "$JCFG" config set-cluster cka-labs \
    --server="$SERVER" --certificate-authority="$CA_FILE" --embed-certs=true
kubectl --kubeconfig "$JCFG" config set-credentials jane \
    --client-certificate=~/cka-labs-out/10/jane.crt \
    --client-key=/tmp/jane.key --embed-certs=true
kubectl --kubeconfig "$JCFG" config set-context jane@cka-labs \
    --cluster=cka-labs --user=jane --namespace=rbac
kubectl --kubeconfig "$JCFG" config use-context jane@cka-labs
kubectl --kubeconfig "$JCFG" get pods
kubectl --kubeconfig "$JCFG" auth whoami
```

Why: every `config` call is scoped with `--kubeconfig`, so your own
`~/.kube/config` is untouched. A kubeconfig may carry the CA as a file
path (`certificate-authority`, minikube's style) or embedded
(`certificate-authority-data`) — `config set-cluster` only accepts a file
path, so decode the data to a file when needed; `--embed-certs=true`
writes it back inline. `whoami` should show user `jane` in group
`developers` (from the CSR's `CN`/`O`).

### Task 9

```bash
kubectl auth can-i --list --as jane -n rbac \
    > ~/cka-labs-out/10/jane-perms.txt
```

### Task 10

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-endpoints
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: [endpoints, services]
  verbs: [get, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: []
EOF
```

Why: the controller fills `monitoring.rules` from every ClusterRole
carrying the label — this is how the built-in `view`/`edit`/`admin`
ClusterRoles are assembled.
