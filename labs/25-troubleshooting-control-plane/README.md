# Lab 25 – Troubleshooting the Control Plane

**Domain:** Troubleshooting (30%) · **Builds on:** Lab 24

Something is wrong inside `kube-system` itself — deployments sit
Pending forever. Find the broken control-plane component, read its
logs, fix it **on the node**, then gather the standard control-plane
evidence.

## Objectives

- Identify a crashed static control-plane pod and read its logs
- Fix a static pod manifest and let the kubelet restart it
- Probe `/livez?verbose` and `/readyz?verbose`
- Inspect the apiserver container with `crictl`
- Read the apiserver serving certificate with `openssl`
- Understand mirror pods (`ownerReferences: Node`)

## Environment

- **Namespace:** `ts-cp` — deployment `stuck` will not schedule.
- **Node access:** `minikube -p cka-labs ssh` → `sudo` for manifests,
  `crictl`, `openssl`, `journalctl`. Static manifests live in
  `/etc/kubernetes/manifests` — edit one and the kubelet restarts the
  pod within ~20s.
- **Output dir:** `~/cka-labs-out/25/`
- **Start here:** `make lab-25`

## Tasks

1. Save `kubectl get pods -n kube-system` to `kube-system-pods.txt`.
   Write the name of the broken component (`kube-scheduler`,
   `kube-apiserver`, `etcd` or `kube-controller-manager`) to
   `broken-component.txt`.
2. Save the broken pod's logs (`--previous` if it restarts) to
   `scheduler.log`.
3. Fix the component on the node. Prove it is Ready and that
   deployment `stuck` finally becomes available.
4. Save `kubectl get --raw /livez?verbose` and `/readyz?verbose` to
   `livez.txt` / `readyz.txt`.
5. From `/var/lib/kubelet/config.yaml` on the node, save the
   `staticPodPath` line to `static-pod-path.txt`, and list the files
   in that directory to `static-manifests.txt`.
6. On the node, save `sudo crictl ps --name kube-apiserver` to
   `apiserver-ps.txt` and the last 20 lines of that container's logs
   to `apiserver-log.txt`.
7. Save `sudo openssl x509 -in
   /var/lib/minikube/certs/apiserver.crt -noout -subject -dates` to
   `apiserver-cert.txt` and the certificate's `subjectAltName` to
   `apiserver-san.txt`.
8. Save `kubectl -n kube-system get pod kube-apiserver-cka-labs -o
   jsonpath='{.metadata.ownerReferences[0].kind}'` to
   `apiserver-owner.txt` — why is a Node the owner of a Pod?
9. Save the `Liveness` stanza from `kubectl -n kube-system describe
   pod kube-controller-manager-cka-labs` to `cm-liveness.txt`.
10. On the node, save the last 20 kubelet journal lines mentioning
    `scheduler` to `kubelet-scheduler.txt`.

## Recovery

If the API server itself ever stops responding while you are editing
static manifests: `minikube -p cka-labs ssh`, restore the file from
`/tmp`, and move on — the kubelet restarts static pods automatically.
`teardown.sh` restores the scheduler manifest from a backup made
during setup.

## Verify

```bash
make verify-25
```

## Clean up

```bash
make teardown-25
```

Restores the scheduler manifest, waits for the mirror pod, deletes
the namespace and the output dir.

## Docs

- https://kubernetes.io/docs/tasks/debug/debug-cluster/
- https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/
- https://kubernetes.io/docs/reference/using-api/health-checks/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/
