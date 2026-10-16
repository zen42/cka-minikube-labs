# Lab 25 – Solution

`$OUT` is `~/cka-labs-out/25`. `CP` is the control-plane node
(`cka-labs`).

### Task 1

```bash
kubectl get pods -n kube-system > $OUT/kube-system-pods.txt
# kube-scheduler-cka-labs is CrashLoopBackOff
echo kube-scheduler > $OUT/broken-component.txt
```

### Task 2

```bash
kubectl -n kube-system logs kube-scheduler-cka-labs --previous \
    > $OUT/scheduler.log
# "failed to load config: open /etc/kubernetes/scheduler.conf.wrong:
#  no such file or directory"
```

### Task 3

```bash
minikube -p cka-labs ssh
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
# fix the flag back to --kubeconfig=/etc/kubernetes/scheduler.conf
# (non-interactive: sudo sed -i 's|scheduler.conf.wrong|scheduler.conf|g' …)
kubectl -n kube-system get pod kube-scheduler-cka-labs   # Running again
kubectl rollout status deploy/stuck -n ts-cp             # finally schedules
```

### Task 4

```bash
kubectl get --raw /livez?verbose  > $OUT/livez.txt
kubectl get --raw /readyz?verbose > $OUT/readyz.txt
```

### Task 5

```bash
minikube -p cka-labs ssh -- sudo grep staticPodPath \
    /var/lib/kubelet/config.yaml > $OUT/static-pod-path.txt
minikube -p cka-labs ssh -- sudo ls /etc/kubernetes/manifests/ \
    > $OUT/static-manifests.txt    # etcd, kube-apiserver,
                                   # kube-controller-manager, kube-scheduler
```

### Task 6

```bash
minikube -p cka-labs ssh -- sudo crictl ps --name kube-apiserver \
    > $OUT/apiserver-ps.txt
cid=$(minikube -p cka-labs ssh -- \
    'sudo crictl ps --name kube-apiserver -q' | head -1)
minikube -p cka-labs ssh -- sudo crictl logs --tail 20 $cid \
    > $OUT/apiserver-log.txt
```

### Task 7

```bash
minikube -p cka-labs ssh -- sudo openssl x509 \
    -in /var/lib/minikube/certs/apiserver.crt -noout -subject -dates \
    > $OUT/apiserver-cert.txt
minikube -p cka-labs ssh -- sudo openssl x509 \
    -in /var/lib/minikube/certs/apiserver.crt -noout -ext subjectAltName \
    > $OUT/apiserver-san.txt
```

### Task 8

```bash
kubectl -n kube-system get pod kube-apiserver-cka-labs \
    -o jsonpath='{.metadata.ownerReferences[0].kind}' \
    > $OUT/apiserver-owner.txt
# "Node" — it is a *mirror pod*: the kubelet owns the real static pod
# (from /etc/kubernetes/manifests) and publishes this read-only mirror
# so the API can see it. kubectl delete on it does nothing durable.
```

### Task 9

```bash
kubectl -n kube-system describe pod kube-controller-manager-cka-labs \
    | grep -A3 Liveness > $OUT/cm-liveness.txt
```

### Task 10

```bash
minikube -p cka-labs ssh -- \
    'sudo journalctl -u kubelet --no-pager | grep -i scheduler | tail -20' \
    > $OUT/kubelet-scheduler.txt
```
