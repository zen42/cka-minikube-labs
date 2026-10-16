# Lab 17 – Kustomize

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 16

Kustomize end to end: a shared base plus dev/prod overlays using name
prefixes, namespaces, common labels, replica/image overrides,
ConfigMap generators, strategic-merge and JSON6902 patches, and the
`kubectl -k` workflow (`apply`, `diff`, `get`, `delete`).

## Objectives

- `kubectl kustomize` / `kustomize build` to render a base
- Overlays: `namespace`, `namePrefix`, `labels`, `replicas`, `images`
- `configMapGenerator` + consuming it via `envFrom`
- Strategic-merge vs JSON6902 patches
- `kubectl apply/diff/get/delete -k`

## Environment

- **Namespaces:** `kz-dev`, `kz-prod` (already created by setup).
- **Base:** written for you to `~/cka-labs-out/17/base/` — a `web`
  Deployment (nginx:1.25, 1 replica), a Service, and a
  `kustomization.yaml`.
- **Output dir:** `~/cka-labs-out/17/` — you build the overlays under
  `~/cka-labs-out/17/overlays/`.
- **Start here:** `make lab-17`

## Tasks

1. Render the base: `kubectl kustomize ~/cka-labs-out/17/base` into
   `~/cka-labs-out/17/base-rendered.yaml`.
2. Create overlay `overlays/dev`: namespace `kz-dev`, namePrefix `dev-`,
   common label `env=dev` (including selectors), `web` scaled to 1
   replica, a `configMapGenerator` named `app-config` with literal
   `LOG_LEVEL=debug`, and a strategic-merge patch that makes the `web`
   container consume it via `envFrom`.
3. Create overlay `overlays/prod`: namespace `kz-prod`, namePrefix
   `prod-`, common label `env=prod` (including selectors), `web` scaled
   to 3 replicas, image `nginx` re-tagged to `1.27`, the same
   `app-config` generator (e.g. `LOG_LEVEL=info`) wired into the pod,
   and a **JSON6902** patch adding `resources.requests.cpu: 100m`.
4. `kustomize build` both overlays into `~/cka-labs-out/17/dev-rendered.yaml`
   and `~/cka-labs-out/17/prod-rendered.yaml`.
5. `kubectl apply -k` both overlays.
6. Edit the prod overlay to 4 replicas, run `kubectl diff -k` and save
   the output **and its exit code** to `~/cka-labs-out/17/diff.txt`,
   then apply.
7. Save `kubectl get -k` output for the prod overlay to
   `~/cka-labs-out/17/prod-get.txt`.
8. `kubectl delete -k` the dev overlay.

## Verify

```bash
make verify-17     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-17   # from the repo root — or ./teardown.sh in this directory
```

Deletes both overlays' resources, the namespaces, and the output dir.

## Docs

- https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_diff/
