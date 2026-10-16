# Lab 17 – Solution

`$OUT` below is `~/cka-labs-out/17`.

### Task 1

```bash
kubectl kustomize $OUT/base > $OUT/base-rendered.yaml
```

### Task 2

```bash
mkdir -p $OUT/overlays/dev
cat > $OUT/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kz-dev
namePrefix: dev-
labels:
- pairs:
    env: dev
  includeSelectors: true
resources:
- ../../base
replicas:
- name: web
  count: 1
configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=debug
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web
    spec:
      template:
        spec:
          containers:
          - name: app
            envFrom:
            - configMapRef:
                name: app-config
EOF
```

Why: kustomize's name-reference transformer rewrites the `configMapRef`
to the generated (prefixed + hashed) ConfigMap name automatically;
patches match the *base* name `web`, not `dev-web`.

### Task 3

```bash
mkdir -p $OUT/overlays/prod
cat > $OUT/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kz-prod
namePrefix: prod-
labels:
- pairs:
    env: prod
  includeSelectors: true
resources:
- ../../base
replicas:
- name: web
  count: 3
images:
- name: nginx
  newTag: "1.27"
configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=info
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web
    spec:
      template:
        spec:
          containers:
          - name: app
            envFrom:
            - configMapRef:
                name: app-config
- target:
    kind: Deployment
    name: web
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 100m
EOF
```

Why: the base container has no `resources` field, so a single `add`
creates the whole subtree — JSON6902 cannot create intermediate paths
one key at a time.

### Task 4

```bash
kustomize build $OUT/overlays/dev  > $OUT/dev-rendered.yaml
kustomize build $OUT/overlays/prod > $OUT/prod-rendered.yaml
```

### Task 5

```bash
kubectl apply -k $OUT/overlays/dev
kubectl apply -k $OUT/overlays/prod
```

### Task 6

```bash
sed -i 's/count: 3/count: 4/' $OUT/overlays/prod/kustomization.yaml
kubectl diff -k $OUT/overlays/prod > $OUT/diff.txt 2>&1
echo "exit code: $?" >> $OUT/diff.txt   # diff exits 1 when changes exist
kubectl apply -k $OUT/overlays/prod
```

### Task 7

```bash
kubectl get -k $OUT/overlays/prod > $OUT/prod-get.txt
```

### Task 8

```bash
kubectl delete -k $OUT/overlays/dev
```
