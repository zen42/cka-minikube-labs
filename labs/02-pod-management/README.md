# Lab 02 – Pod Management

**Domain:** Workloads & Scheduling (15%) · **Builds on:** Lab 01

Create, inspect, exec into, copy from, and forward to Pods — the everyday
`kubectl` workflow, including multi-container pods and crash-looping pods.

## Objectives

- `kubectl run` pods (images, ports, env, restart policy, labels)
- `kubectl logs` (incl. `--previous`, `-c`, `--tail`)
- `kubectl exec`, `kubectl cp`, `kubectl port-forward`, `kubectl wait`,
  `kubectl describe`

## Environment

- **Namespace:** `pods`
- **Seeded for you:** pod `crasher` (busybox that exits 1 — CrashLoopBackOff)
  and pod `multi` (`app` nginx + `sidecar` busybox sharing an `emptyDir`
  volume mounted at `/shared`).
- **Output dir:** `~/cka-labs-out/02/`
- **Start here:** `make lab-02`

## Tasks

1. In namespace `pods`, create pod `web` with image `nginx:1.27`, port `80`,
   and label `app=web`.
2. Create pod `busy` in `pods`: image `busybox:1.36`, restart policy `Never`,
   environment variable `GREETING=hello`, running the command `sleep 3600`.
3. Pod `crasher` is crash-looping. From its **previous** container logs find
   the fatal error line and save it to `~/cka-labs-out/02/crash-reason.txt`.
4. Save the last 20 lines of the `sidecar` container's logs of pod `multi`
   to `~/cka-labs-out/02/sidecar.log`.
5. Using `kubectl exec` in container `app` of pod `multi`, read
   `/shared/status.txt` and write its content to
   `~/cka-labs-out/02/status.txt`.
6. Using `kubectl exec`, create a file `/tmp/hello.txt` containing the text
   `world` inside pod `busy`.
7. Using `kubectl cp`, copy `/etc/nginx/nginx.conf` out of pod `web` to
   `~/cka-labs-out/02/nginx.conf`.
8. Run `kubectl port-forward pod/web 8080:80 -n pods` and save
   `curl -s localhost:8080` output to `~/cka-labs-out/02/index.html`.
   (Stop the port-forward afterwards.)
9. Wait for pod `web` to be Ready with `kubectl wait`, then write the name
   of the node running `web` to `~/cka-labs-out/02/web-node.txt` using
   `-o jsonpath`.
10. Save `kubectl describe pod crasher -n pods` to
    `~/cka-labs-out/02/crasher-describe.txt`.
11. Delete pod `crasher`.

## Verify

```bash
make verify-02     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-02   # from the repo root — or ./teardown.sh in this directory
```

## Docs

- https://kubernetes.io/docs/concepts/workloads/pods/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
- https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/
