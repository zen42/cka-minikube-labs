# Lab 03 – Solution

### Task 1

```bash
kubectl get pods -n config            # CreateContainerConfigError
kubectl describe pod -n config -l app=reader | grep -A3 Events
kubectl create configmap app-config -n config \
    --from-literal=APP_MODE=production --from-literal=LOG_LEVEL=info
```

Why: `envFrom: configMapRef app-config` is not `optional`, so the kubelet
blocks container creation until the ConfigMap exists; creating the missing
object is the fix — no pod edit needed.

### Task 2

```bash
kubectl create configmap app-props -n config \
    --from-file=labs/03-configmaps-secrets/manifests/app.properties
```

### Task 3

```bash
kubectl create secret generic db-creds -n config \
    --from-literal=username=admin --from-literal='password=S3cr3t!'
```

### Task 4

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /tmp/web.key -out /tmp/web.crt -days 1 \
    -subj '/CN=web.example.com'
kubectl create secret tls web-tls -n config \
    --cert=/tmp/web.crt --key=/tmp/web.key
```

### Task 5

```bash
kubectl create secret docker-registry regcred -n config \
    --docker-server=registry.example.com --docker-username=bob \
    --docker-password=pass --docker-email=bob@example.com
```

### Task 6

```bash
kubectl apply -n config -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: env-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    env:
    - name: MODE
      valueFrom:
        configMapKeyRef: {name: app-config, key: APP_MODE}
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef: {name: db-creds, key: password}
EOF
```

### Task 7

```bash
kubectl apply -n config -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: vol-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: props, mountPath: /etc/props, readOnly: true}
    - {name: creds, mountPath: /etc/creds, readOnly: true}
  volumes:
  - name: props
    configMap: {name: app-props}
  - name: creds
    secret: {secretName: db-creds}
EOF
```

### Task 8

```bash
kubectl patch configmap app-config -n config \
    --type=merge -p '{"data":{"LOG_LEVEL":"debug"}}'
kubectl rollout restart deployment reader -n config
kubectl rollout status deployment reader -n config
```

Why: env vars come from the ConfigMap at container creation; existing pods
still see the old values, so a rollout restart is required.

### Task 9

```bash
kubectl apply -n config -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: static-config
immutable: true
data:
  version: "1"
EOF
```

### Task 10

```bash
kubectl get secret db-creds -n config \
    -o jsonpath='{.data.password}' | base64 -d \
    > ~/cka-labs-out/03/password.txt
```
