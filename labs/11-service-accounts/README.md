# Lab 11 – Service Accounts

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 10

In-cluster identity: ServiceAccounts, mounted tokens, calling the API from a
pod, TokenRequest vs projected volumes, imagePullSecrets, and SA RBAC.

## Objectives

- `kubectl create serviceaccount`, bind roles to `sa:<name>` subjects
- Call the API from inside a pod with the mounted token + CA
- `automountServiceAccountToken`, `kubectl create token`, projected tokens
- Attach `imagePullSecrets`; ClusterRoleBinding a SA to the `view` role

## Environment

- **Namespace:** `sa`, with pod `legacy` (default SA) and Role `pod-lister`
  seeded — the role exists but is bound to nobody.
- **Output dir:** `~/cka-labs-out/11/`
- **Start here:** `make lab-11`
- SA subjects in bindings look like `system:serviceaccount:<ns>:<name>` —
  `--as=system:serviceaccount:sa:app-sa` impersonates one for `auth can-i`.

## Tasks

1. Create ServiceAccount `app-sa` in namespace `sa`.
2. Create RoleBinding `app-sa-lister` binding ServiceAccount `sa:app-sa` to
   the seeded Role `pod-lister`. Confirm
   `kubectl auth can-i list pods -n sa --as=system:serviceaccount:sa:app-sa`
   is `yes` and `delete pods` is `no`.
3. Create pod `api-client` (image `curlimages/curl:8.14.1`, `sleep 3600`)
   running as `serviceAccountName: app-sa`.
4. From inside `api-client`, list the namespace's pods through the API using
   the mounted token and CA, and save the JSON to
   `~/cka-labs-out/11/pods-via-api.txt`:
   `kubectl exec api-client -n sa -- sh -c 'curl -sS --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc/api/v1/namespaces/sa/pods'`
   (single-quoted, so `$(cat ...)` reads the token *inside* the pod).
5. Create pod `no-token` (busybox:1.36 `sleep 3600`) with
   `automountServiceAccountToken: false`.
6. `kubectl create token app-sa -n sa --duration=1h` → save to
   `~/cka-labs-out/11/token.txt`; then run `auth whoami` with that token
   and save the output to `~/cka-labs-out/11/whoami.txt`. (Your context's
   client certificate wins over `--token`, so pass
   `--kubeconfig=/dev/null` plus explicit `--server` /
   `--certificate-authority` to force token-only auth.)
7. Create pod `projected-token` (busybox:1.36 `sleep 3600`) mounting a
   `projected` volume whose `serviceAccountToken` source has audience
   `vault`, `expirationSeconds: 3600`, path `token`, at
   `/var/run/secrets/tokens`.
8. Create a `docker-registry` secret `regcred` (server
   `registry.example.com`, user `bob`, password `pass`) and attach it to
   `app-sa` in `imagePullSecrets`.
9. Create ClusterRoleBinding `app-sa-view` granting the built-in
   ClusterRole `view` to `sa:app-sa` cluster-wide.
10. Save `kubectl get sa,rolebinding -n sa -o wide` to
    `~/cka-labs-out/11/sa-report.txt`.

## Verify

```bash
make verify-11     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-11   # from the repo root — or ./teardown.sh in this directory
```

Deletes namespace `sa`, the ClusterRoleBinding, and the output dir.

## Docs

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/token-request-v1/
- https://kubernetes.io/docs/concepts/security/service-accounts/
