# Lab 06 – Solution

### Task 1

```bash
kubectl create deployment web --image=busybox:1.36 --replicas=3 -n services \
    -- sh -c 'mkdir -p /www && echo web > /www/index.html \
              && httpd -f -p 80 -h /www'
kubectl expose deployment web -n services --name=web-svc --port=80 --target-port=80
```

Why: `kubectl create deployment` labels the pods `app=web` automatically
(the deployment name becomes the label), and `kubectl expose` builds a
Service whose selector matches that label.

### Task 2

```bash
kubectl expose deployment web -n services --name=web-nodeport \
    --type=NodePort --port=80 --target-port=80
kubectl patch svc web-nodeport -n services \
    -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30080}]}}'
```

(Or write the Service manifest directly — `--dry-run=client -o yaml` is
your friend.)

### Task 3

```bash
kubectl expose deployment web -n services --name=web-lb \
    --type=LoadBalancer --port=80 --target-port=80
kubectl get svc web-lb -n services   # EXTERNAL-IP stays <pending>
```

Why: on bare-metal/minikube there is no cloud LB provider; the Service
still works via its ClusterIP. `minikube tunnel` would assign one.

### Task 4

```bash
kubectl get endpoints legacy-svc -n services     # <none>
kubectl describe svc legacy-svc -n services      # Selector: app=legacy-ap
kubectl patch svc legacy-svc -n services \
    -p '{"spec":{"selector":{"app":"legacy-api"}}}'
kubectl get endpoints legacy-svc -n services     # 2 pod IPs
```

Why: a Service has no endpoints when its selector matches zero pods —
compare the selector with `kubectl get pods -n services --show-labels`.

### Task 5

```bash
kubectl apply -n services -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  selector: {app: web}
  ports:
  - {port: 80, targetPort: 80}
EOF
kubectl run dns-test --rm -i --restart=Never -n services \
    --image=busybox:1.36 -- nslookup web-headless.services.svc.cluster.local
```

Why: headless Services skip the virtual IP — DNS returns the individual
pod IPs (used for StatefulSets and client-side load balancing).

### Task 6

```bash
kubectl apply -n services -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
  ports:
  - {port: 5432}
EOF
```

### Task 7

```bash
kubectl apply -n services -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: manual-svc
spec:
  ports:
  - {port: 8080, targetPort: 80}
EOF
POD_IP=$(kubectl get pod -n services -l app=web \
    -o jsonpath='{.items[0].status.podIP}')
kubectl apply -n services -f - <<EOF
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: manual-svc-1
  labels:
    kubernetes.io/service-name: manual-svc
addressType: IPv4
endpoints:
  - addresses: ["$POD_IP"]
    conditions:
      ready: true
ports:
  - {port: 80, protocol: TCP}
EOF
```

Why: Services without a selector get no automatic EndpointSlice — you
manage the addresses yourself (external DBs, migration targets).

### Task 8

```bash
kubectl get endpointslices -n services \
    -l kubernetes.io/service-name=web-svc -o wide \
    > ~/cka-labs-out/06/web-endpoints.txt
```

### Task 9

```bash
kubectl patch svc web-svc -n services -p \
    '{"spec":{"ports":[{"name":"http","port":80,"targetPort":80},
                       {"name":"alt","port":8080,"targetPort":80}]}}'
```

### Task 10

```bash
kubectl patch svc web-svc -n services \
    -p '{"spec":{"sessionAffinity":"ClientIP"}}'
```
