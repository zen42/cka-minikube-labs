# Lab 18 – CRDs & Operators

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 17

Two halves: write your own `CustomResourceDefinition` by hand (schema
validation, shortNames, printer columns), then install a real operator —
cert-manager via its helm chart — and drive it through its CRDs
(`ClusterIssuer`, `Certificate`).

## Objectives

- CRD anatomy: group/version/scope, `openAPIV3Schema` validation,
  `shortNames`, `additionalPrinterColumns`
- `kubectl explain` / `api-resources` against a custom API
- Validation: a CR violating the schema must be rejected
- Operator install via helm; `ClusterIssuer` + `Certificate` end-to-end

## Environment

- **Namespaces:** `crd-demo` (created by setup), `cert-manager`
  (created by `helm install --create-namespace` in task 7).
- **Output dir:** `~/cka-labs-out/18/`
- **Start here:** `make lab-18`
- cert-manager chart: repo `https://charts.jetstack.io`, pinned to
  `CERT_MANAGER_VERSION` in `versions.env` (v1.21.2).
- Helm and kubectl talk to the cluster through your current kubectl
  context — make sure it is `cka-labs`
  (`kubectl config use-context cka-labs`).

## Tasks

1. Create a CRD `crontabs.stable.example.com`: group
   `stable.example.com`, version `v1` (served + storage), scope
   `Namespaced`, kind `CronTab` (plural `crontabs`, shortName `ct`),
   with an `openAPIV3Schema` requiring `spec.cronSpec` (string),
   `spec.image` (string), `spec.replicas` (integer, minimum 1,
   maximum 10), and `additionalPrinterColumns` for Spec, Replicas, Age.
2. Save `kubectl explain crontab.spec` to
   `~/cka-labs-out/18/explain.txt`.
3. Create two CRs in `crd-demo`: `my-new-cron-object` (replicas 1) and
   `my-other-cron` (replicas 3).
4. Prove validation works: write a manifest with `replicas: 20` to
   `~/cka-labs-out/18/invalid.yaml`, try to apply it, and save the
   apiserver's rejection to `~/cka-labs-out/18/invalid-error.txt`.
5. Save `kubectl get ct -n crd-demo` with custom columns
   NAME/SPEC/REPLICAS to `~/cka-labs-out/18/ct.txt`.
6. Save `kubectl api-resources --api-group=stable.example.com` to
   `~/cka-labs-out/18/api-resources.txt`.
7. Add the `jetstack` helm repo (`https://charts.jetstack.io`) and
   install `cert-manager` (pinned version, `--set crds.enabled=true`)
   into new namespace `cert-manager`. Wait for its three deployments.
8. Create a `ClusterIssuer` named `selfsigned` (`selfSigned: {}`) and a
   `Certificate` `demo-cert` in `crd-demo` (secretName `demo-cert-tls`,
   dnsName `demo.example.com`, duration `24h`, issuerRef kind
   `ClusterIssuer`). Wait until the Certificate reports `Ready=True`
   and the Secret contains `tls.crt`.
9. Save a listing of the CRDs cert-manager installed (there are ≥ 6)
   to `~/cka-labs-out/18/cert-manager-crds.txt`.
10. Save `kubectl describe crd certificates.cert-manager.io` to
    `~/cka-labs-out/18/describe-crd.txt`.

## Verify

```bash
make verify-18     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-18   # from the repo root — or ./teardown.sh in this directory
```

Deletes the Certificate/Issuer, uninstalls cert-manager, removes its
CRDs and ours, deletes the namespaces and the output dir.

## Docs

- https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/
- https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
- https://helm.sh/docs/intro/using_helm/
