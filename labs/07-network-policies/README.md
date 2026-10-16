# Lab 07 – Network Policies

**Domain:** Services & Networking (20%) · **Builds on:** Lab 06

Firewalls for pods: default-deny plus incremental ingress/egress allowlists,
enforced by the cluster's Calico CNI.

## Objectives

- `NetworkPolicy` `podSelector`, `policyTypes`, ingress/egress rules
- `podSelector` vs `namespaceSelector` in `from:`/`to:` peers
- Allow DNS egress; the AND-vs-OR semantics of multiple `from` items

## Environment

- **Namespaces:** `netpol` (workloads), `other` (a probing pod).
- **Seeded for you:** in `netpol` — pods `frontend`, `backend`, `db`, each a
  busybox httpd server answering with its own name on port 80 (labels
  `app=<name>`) plus a same-named ClusterIP Service. In `other` — pod
  `outsider` (busybox, `sleep 3600`).
- **Output dir:** `~/cka-labs-out/07/`
- **Start here:** `make lab-07`
- Probe connectivity from inside pods:
  `kubectl exec frontend -n netpol -- wget -qO- -T 3 http://backend.netpol`

## Tasks

All policies go in namespace `netpol`. Policies are additive — order does
not matter.

1. Create a default-deny-ingress policy `default-deny-ingress` selecting
   ALL pods (`podSelector: {}`) with `policyTypes: [Ingress]` — no rules.
2. `allow-frontend-ingress`: allow ingress to `app=frontend` on TCP port 80
   from anywhere.
3. `allow-frontend-to-backend`: allow ingress to `app=backend` on TCP 80
   only from pods labeled `app=frontend` **in this namespace**.
4. `allow-backend-to-db`: allow ingress to `app=db` on TCP 80 only from
   `app=backend` pods.
5. `db-egress-dns-only`: an egress policy for `app=db` allowing ONLY TCP+UDP
   port 53, to pods in the `kube-system` namespace
   (`namespaceSelector` matching `kubernetes.io/metadata.name:
   kube-system`).
6. Label namespace `other` with `team=platform`, then create
   `allow-platform-ns-to-backend`: allow ingress to `app=backend` on TCP 80
   from *any pod in namespaces* labeled `team=platform`. (This is a
   separate policy — inside one `from` item, `podSelector` AND
   `namespaceSelector` combine; separate list items are OR-ed.)
7. Save `kubectl get networkpolicy -n netpol` to
   `~/cka-labs-out/07/netpols.txt`.

## Verify

```bash
make verify-07     # from the repo root — or ./verify.sh in this directory
```

Checks both the policy objects AND the enforced connectivity matrix
(e.g. frontend→db must fail, backend→db must succeed, db may only do DNS).

## Clean up

```bash
make teardown-07   # from the repo root — or ./teardown.sh in this directory
```

## Docs

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
