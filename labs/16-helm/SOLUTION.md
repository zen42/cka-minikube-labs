# Lab 16 – Solution

### Task 1

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm search repo podinfo --versions > ~/cka-labs-out/16/search.txt
```

### Task 2

```bash
helm show values podinfo/podinfo --version 6.15.0 \
    > ~/cka-labs-out/16/values-default.yaml
```

### Task 3

```bash
helm install frontend podinfo/podinfo -n helm --create-namespace \
    --version 6.15.0 --set replicaCount=2
kubectl rollout status deploy/frontend-podinfo -n helm
```

Why: the release is named `frontend` and the chart `podinfo`, so the
Deployment is `frontend-podinfo`.

### Task 4

```bash
helm upgrade frontend podinfo/podinfo -n helm --version 6.15.0 \
    --set replicaCount=3 --set ui.message="hello cka"
kubectl get deploy frontend-podinfo -n helm -o yaml | grep -A2 UI_MESSAGE
```

Why: the podinfo chart maps `.Values.ui.message` to the env var
`PODINFO_UI_MESSAGE`; the release is now at revision 2.

### Task 5

```bash
helm history frontend -n helm > ~/cka-labs-out/16/history.txt
helm rollback frontend 1 -n helm
```

Why: rollback does not reuse revision 1 — it applies revision 1's state
as a new revision 3, so `replicaCount` returns to 2.

### Task 6

```bash
helm get values frontend -n helm -o yaml \
    > ~/cka-labs-out/16/get-values.yaml
```

### Task 7

```bash
cd ~/cka-labs-out/16 && helm create webapp   # creates ./webapp
# edit ~/cka-labs-out/16/webapp/values.yaml:
#   replicaCount: 2, image.repository: nginx, image.tag: "1.27"
sed -i -e 's/^replicaCount:.*/replicaCount: 2/' \
    -e 's/^  repository:.*/  repository: nginx/' \
    -e 's/^  tag:.*/  tag: "1.27"/' \
    ~/cka-labs-out/16/webapp/values.yaml
helm lint ~/cka-labs-out/16/webapp
helm template webapp ~/cka-labs-out/16/webapp \
    > ~/cka-labs-out/16/webapp-rendered.yaml
helm install webapp ~/cka-labs-out/16/webapp -n helm
```

### Task 8

```bash
helm pull podinfo/podinfo --version 6.15.0 -d ~/cka-labs-out/16
```

### Task 9

```bash
helm uninstall webapp -n helm
```

### Task 10

```bash
helm list -A -o json > ~/cka-labs-out/16/releases.json
```
