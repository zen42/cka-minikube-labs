# Lab 16 – Helm

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 15

Helm 3 end to end: repositories, chart inspection, install/upgrade/rollback,
custom values, scaffolding your own chart, and packaging.

## Objectives

- `helm repo` / `helm search repo` / `helm show values`
- `helm install` / `upgrade` / `history` / `rollback` / `get values`
- `helm create` / `lint` / `template` / `pull` / `uninstall` / `list`

## Environment

- **Namespace:** `helm` (you create it in task 3 via `--create-namespace`).
- **Output dir:** `~/cka-labs-out/16/`
- **Start here:** `make lab-16`
- Chart: `podinfo` from `https://stefanprodan.github.io/podinfo`, pinned to
  version **6.15.0** (see `versions.env`, `PODINFO_CHART_VERSION`).
- Helm talks to the cluster through your current kubectl context — make
  sure it is `cka-labs` (`kubectl config use-context cka-labs`).

## Tasks

1. Add the repo `podinfo` (`https://stefanprodan.github.io/podinfo`), run
   `helm repo update`, and save `helm search repo podinfo --versions` to
   `~/cka-labs-out/16/search.txt`.
2. Save the chart's default values for version `6.15.0` to
   `~/cka-labs-out/16/values-default.yaml`.
3. Install release `frontend` from `podinfo/podinfo` version `6.15.0`
   into a new namespace `helm` with `replicaCount=2`.
4. Upgrade `frontend`: `replicaCount=3` and `ui.message="hello cka"`.
   Confirm the deployment picked up `PODINFO_UI_MESSAGE`.
5. Save `helm history frontend -n helm` to
   `~/cka-labs-out/16/history.txt`, then roll the release back to
   revision 1 (a rollback creates a *new* revision — 3).
6. Save the release's user-supplied values (`helm get values`) to
   `~/cka-labs-out/16/get-values.yaml`.
7. `helm create` a chart named `webapp` inside `~/cka-labs-out/16/`,
   edit `values.yaml` to use image `nginx` tag `1.27` and
   `replicaCount: 2`, then `helm lint` it, render it with
   `helm template` into `~/cka-labs-out/16/webapp-rendered.yaml`, and
   install it as release `webapp` in namespace `helm`.
8. `helm pull` the `podinfo/podinfo` chart (version `6.15.0`) into
   `~/cka-labs-out/16/` — the `.tgz` archive should land there.
9. Uninstall release `webapp` (leave `frontend` running).
10. Save `helm list -A -o json` to `~/cka-labs-out/16/releases.json`.

## Verify

```bash
make verify-16     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-16   # from the repo root — or ./teardown.sh in this directory
```

Uninstalls both releases, deletes the namespace, removes the repo entry
and the output dir.

## Docs

- https://helm.sh/docs/intro/using_helm/
- https://helm.sh/docs/helm/helm_upgrade/
- https://helm.sh/docs/helm/helm_rollback/
- https://helm.sh/docs/chart_template_guide/getting_started/
