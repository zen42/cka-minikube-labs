# Lab 10 – RBAC for Users & Groups

**Domain:** Cluster Architecture, Installation & Configuration (25%) ·
**Builds on:** Lab 01

Who can do what: `Role`/`RoleBinding` (namespaced), `ClusterRole`/
`ClusterRoleBinding`, `kubectl auth can-i`, aggregated roles, and a real
certificate-based user.

## Objectives

- Roles, RoleBindings, ClusterRoles, ClusterRoleBindings for users & groups
- `kubectl auth can-i` / `auth whoami` / `can-i --list`
- CertificateSigningRequest → a kubeconfig for user `jane`
- Aggregated ClusterRoles (`aggregationRule`)

## Environment

- **Namespace:** `rbac`, with a seeded deployment `app`.
- **Seeded bug:** RoleBinding `dev-can-view` grants user `dave` a Role named
  `pod-viewer` — which does not exist. `kubectl describe rolebinding
  dev-can-view -n rbac` shows the dangling reference (bindings do not
  validate that the role exists — it silently grants nothing).
- **Output dir:** `~/cka-labs-out/10/`
- **Start here:** `make lab-10`
- A RoleBinding that references a **ClusterRole** grants only the namespaced
  resources of that ClusterRole, and only inside the RoleBinding's own
  namespace (task 5 shows this).
- `roleRef` is immutable — "editing" a binding's role means delete + recreate.

## Tasks

1. Create Role `pod-reader` in `rbac` allowing `get`, `list`, `watch` on
   `pods` (use `kubectl create role`).
2. Create RoleBinding `jane-pod-reader` binding User `jane` to `pod-reader`.
3. Check `kubectl auth can-i get pods -n rbac --as jane` and
   `kubectl auth can-i create deployments -n rbac --as jane`; write the two
   answers, one per line (`yes` then `no`), to
   `~/cka-labs-out/10/can-i.txt`.
4. Create ClusterRole `node-viewer` (`get`,`list`,`watch` on `nodes`) and
   ClusterRoleBinding `ops-node-viewer` binding **Group** `ops` to it.
   Confirm `kubectl auth can-i list nodes --as=someone --as-group=ops`.
5. Create ClusterRole `ns-pod-reader` (`get`,`list` on `pods`) and bind it
   to `jane` with a RoleBinding `jane-ns-pods` in namespace `default`. Note
   how jane can list pods in `default` but NOT in `kube-system`.
6. Fix `dev-can-view` so `dave` gets the `pod-reader` role. (`roleRef` is
   immutable — delete the binding and recreate it.)
7. Create a certificate-based user `jane`: generate a key and CSR with
   `openssl` (`CN=jane`, `O=developers`), create a
   CertificateSigningRequest `jane` (`signerName:
   kubernetes.io/kube-apiserver-client`, usages `client auth`,
   `expirationSeconds: 86400`), `kubectl certificate approve jane`, and
   extract the issued certificate from `.status.certificate`.
8. Build a kubeconfig for jane at `~/cka-labs-out/10/jane.kubeconfig`:
   cluster `cka-labs` (server + CA from
   `kubectl config view --minify --raw`; the CA may be a
   `certificate-authority` file path or embedded
   `certificate-authority-data` — `config set-cluster` takes the file
   form, so decode the data to a file if needed), credentials from jane's
   cert/key, context `jane@cka-labs` with default namespace `rbac`,
   current-context set. Do not modify your own `~/.kube/config`. Confirm
   `kubectl --kubeconfig <file> auth whoami` reports `jane` /
   `developers`.
9. Save `kubectl auth can-i --list --as jane -n rbac` to
   `~/cka-labs-out/10/jane-perms.txt`.
10. Aggregated roles: create ClusterRole `monitoring-endpoints` labeled
    `rbac.example.com/aggregate-to-monitoring: "true"` allowing `get`,`list`
    on `endpoints` and `services`; create ClusterRole `monitoring` with an
    `aggregationRule` selecting that label (and no inline rules).

## Verify

```bash
make verify-10
```

## Clean up

```bash
make teardown-10
```

Deletes namespace `rbac`, the RoleBinding in `default`, all ClusterRoles/
ClusterRoleBindings/CSRs the lab creates, and the output dir.

## Docs

- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/
