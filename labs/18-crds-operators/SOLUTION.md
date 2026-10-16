# Lab 18 – Solution

### Task 1

```bash
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: crontabs.stable.example.com
spec:
  group: stable.example.com
  scope: Namespaced
  names:
    plural: crontabs
    singular: crontab
    kind: CronTab
    shortNames: [ct]
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              cronSpec:  {type: string}
              image:     {type: string}
              replicas:
                type: integer
                minimum: 1
                maximum: 10
    additionalPrinterColumns:
    - {name: Spec,     type: string,  jsonPath: .spec.cronSpec}
    - {name: Replicas, type: integer, jsonPath: .spec.replicas}
    - {name: Age,      type: date,    jsonPath: .metadata.creationTimestamp}
EOF
kubectl wait --for=condition=Established \
    crd/crontabs.stable.example.com --timeout=60s
```

### Task 2

```bash
kubectl explain crontab.spec > ~/cka-labs-out/18/explain.txt
```

### Task 3

```bash
kubectl apply -n crd-demo -f - <<'EOF'
apiVersion: stable.example.com/v1
kind: CronTab
metadata: {name: my-new-cron-object}
spec: {cronSpec: "* * * * */5", image: some-cron-image, replicas: 1}
---
apiVersion: stable.example.com/v1
kind: CronTab
metadata: {name: my-other-cron}
spec: {cronSpec: "*/10 * * * *", image: some-cron-image, replicas: 3}
EOF
```

### Task 4

```bash
cat > ~/cka-labs-out/18/invalid.yaml <<'EOF'
apiVersion: stable.example.com/v1
kind: CronTab
metadata: {name: invalid-cron, namespace: crd-demo}
spec: {cronSpec: "* * * * *", image: some-cron-image, replicas: 20}
EOF
kubectl apply -f ~/cka-labs-out/18/invalid.yaml \
    > ~/cka-labs-out/18/invalid-error.txt 2>&1   # fails: replicas <= 10
```

### Task 5

```bash
kubectl get ct -n crd-demo \
    -o custom-columns=NAME:.metadata.name,SPEC:.spec.cronSpec,REPLICAS:.spec.replicas \
    > ~/cka-labs-out/18/ct.txt
```

### Task 6

```bash
kubectl api-resources --api-group=stable.example.com \
    > ~/cka-labs-out/18/api-resources.txt
```

### Task 7

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
    -n cert-manager --create-namespace \
    --version v1.21.2 --set crds.enabled=true
kubectl -n cert-manager wait --for=condition=Available deploy --all \
    --timeout=180s
```

### Task 8

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: selfsigned}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: demo-cert, namespace: crd-demo}
spec:
  secretName: demo-cert-tls
  dnsNames: [demo.example.com]
  duration: 24h
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
EOF
kubectl -n crd-demo wait --for=condition=Ready certificate/demo-cert \
    --timeout=120s
kubectl -n crd-demo get secret demo-cert-tls   # contains tls.crt
```

### Task 9

```bash
kubectl get crd | grep cert-manager \
    > ~/cka-labs-out/18/cert-manager-crds.txt
```

### Task 10

```bash
kubectl describe crd certificates.cert-manager.io \
    > ~/cka-labs-out/18/describe-crd.txt
```
