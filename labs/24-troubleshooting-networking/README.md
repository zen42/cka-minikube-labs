# Lab 24 – Troubleshooting Services & Networking

**Domain:** Troubleshooting (30%) · **Builds on:** Lab 23

Five healthy pods, four broken layers of plumbing, and a dead cluster
DNS. Work the standard service-debugging ladder until everything
responds.

## Objectives

- The networking troubleshooting flow: **pod → service → endpoints →
  networkpolicy → DNS → ingress**
- `endpoints`/`endpointslices` as the service-truth check
- NetworkPolicy: default-deny plus a narrow allow
- CoreDNS scale and `nslookup` from inside the cluster
- Ingress backends and `Host` routing

## Environment

- **Namespace:** `ts-net` — pods `web`, `api`, `db`, `client`,
  `other` are all Running; the plumbing around them is broken.
- **Output dir:** `~/cka-labs-out/24/`
- **Start here:** `make lab-24`
- The ingress controller is `ingress-nginx-controller` in namespace
  `ingress-nginx` — probe it with a `Host:` header.

## Tasks

1. Start at the bottom: `nslookup
   kubernetes.default.svc.cluster.local` fails from a pod. Find why
   cluster DNS is down (look in `kube-system`) and restore it.
2. Service `web-svc` has no endpoints. Fix it and prove
   `http://web-svc.ts-net` serves the pod's content.
3. `http://api-svc.ts-net` times out or refuses despite healthy
   endpoints. Fix the service and prove it serves the API.
4. Nothing can reach pod `db` — a NetworkPolicy denies all ingress.
   **Without deleting it**, add NetworkPolicy `allow-client-to-db`
   that lets only pods labelled `app=client` reach `db` on port 80.
   Prove `client` gets `db-ok` and `other` still fails.
5. `curl -H 'Host: web.ts.local'
   http://ingress-nginx-controller.ingress-nginx` does not return the
   web page. Fix the ingress and prove it works.
6. Save `kubectl -n kube-system get ds kube-proxy` and
   `kubectl -n kube-system logs ds/kube-proxy --tail=20` to
   `kube-proxy.txt` / `kube-proxy-log.txt`, and
   `kubectl get endpointslices -n ts-net` to `endpointslices.txt`.

## Verify

```bash
make verify-24     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-24   # from the repo root — or ./teardown.sh in this directory
```

Restores coredns to its original replica count, deletes the namespace
and the output dir.

## Docs

- https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/concepts/services-networking/ingress/
