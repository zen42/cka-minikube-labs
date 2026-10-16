# Lab 08 – Ingress & Gateway API

**Domain:** Services & Networking (20%) · **Builds on:** Lab 07

L7 routing two ways: the classic `Ingress` resource (NGINX Ingress
Controller addon) and the newer `Gateway API` (`Gateway`/`HTTPRoute` via
NGINX Gateway Fabric).

## Objectives

- `Ingress` + `ingressClassName`, host/path routing, TLS secret
- `GatewayClass`, `Gateway`, `HTTPRoute` — path and header matching

## Environment

- **Namespace:** `ingress` (the lab apps; the controllers live in
  `ingress-nginx` and `nginx-gateway`).
- **Seeded for you (by setup.sh, not a task):** deployments+services `shop`
  and `blog` (busybox httpd, each answers with its name on `/` and
  `/<name>/`); Gateway API CRDs + NGINX Gateway Fabric (the version pinned
  in `versions.env`,
  GatewayClass `nginx`) if not already installed. NGF stays installed after
  teardown.
- **Ingress controller:** the `ingress` minikube addon (NGINX) —
  IngressClass `nginx`, reachable in-cluster at
  `ingress-nginx-controller.ingress-nginx.svc.cluster.local`.
- **Output dir:** `~/cka-labs-out/08/`
- **Start here:** `make lab-08`
- Probes run from inside the cluster. To test a Host header without DNS:
  `kubectl run p --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- --header 'Host: blog.example.com' http://ingress-nginx-controller.ingress-nginx/`
  For `apps.example.com` use `https://…` once TLS is configured — plain
  HTTP gets a `308` redirect to a name that does not resolve in-cluster
  (busybox wget does not verify the self-signed cert).
- **NGF data plane:** each `Gateway` named `X` gets a Service+Deployment
  `X-nginx` in the same namespace — that is what you probe.
- setup.sh disables nginx `reuseport` on the ingress controller — under
  this driver it blackholes ~half of new connections after config reloads
  (an environment quirk of this lab setup).

## Tasks

1. Create Ingress `apps-ingress` with `ingressClassName: nginx`, host
   `apps.example.com`, and rules routing path `/shop` (Prefix) → service
   `shop` port 80 and `/blog` (Prefix) → service `blog` port 80.
2. Add TLS: generate a self-signed cert for `apps.example.com`, store it as
   TLS secret `apps-tls`, and reference it in `apps-ingress`'s `spec.tls`.
3. Create a second Ingress `blog-ingress`: host `blog.example.com`, path
   `/` → service `blog` port 80.
4. Save `kubectl get ingressclass` to
   `~/cka-labs-out/08/ingressclasses.txt` and
   `kubectl describe ingress apps-ingress -n ingress` to
   `~/cka-labs-out/08/apps-ingress.txt`.
5. Create Gateway `apps-gateway` in namespace `ingress` with
   `gatewayClassName: nginx` and one listener `http` (HTTP, port 80).
   Wait until it reports `Programmed=True` (NGF provisions a data-plane
   Deployment + Service `apps-gateway-nginx` — this can take a minute).
6. Create HTTPRoute `shop-route` attached to `apps-gateway`, hostname
   `shop.gw.example.com`, rule `/` → `shop:80`.
7. Create HTTPRoute `apps-route` attached to `apps-gateway`, hostname
   `apps.gw.example.com`, with two rules: PathPrefix `/shop` → `shop:80`
   and `/blog` → `blog:80`.
8. Create HTTPRoute `canary-route` attached to `apps-gateway`, hostname
   `canary.gw.example.com`: a rule matching header `x-version: v2` →
   `blog:80`, and a default rule → `shop:80`.
9. Save `kubectl get gateway,httproute -n ingress` to
   `~/cka-labs-out/08/gateway.txt`.

## Verify

```bash
make verify-08     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-08   # from the repo root — or ./teardown.sh in this directory
```

Deletes namespace `ingress` (the Gateway's data plane goes with it).
NGINX Gateway Fabric and the Gateway API CRDs stay installed.

## Docs

- https://kubernetes.io/docs/concepts/services-networking/ingress/
- https://kubernetes.io/docs/concepts/services-networking/gateway/
- https://gateway-api.sigs.k8s.io/ (upstream project docs)
