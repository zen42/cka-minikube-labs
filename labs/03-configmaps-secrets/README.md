# Lab 03 – ConfigMaps & Secrets

**Domain:** Workloads & Scheduling (15%) · **Builds on:** Lab 02

Inject configuration into pods three ways — env vars, `envFrom`, and volume
mounts — and learn the different Secret types you will meet in the exam.

## Objectives

- `kubectl create configmap` (--from-literal, --from-file), `envFrom`
- `kubectl create secret generic/tls/docker-registry`
- `configMapKeyRef`, `secretKeyRef`, `immutable`, `rollout restart`
- Decode secret data with jsonpath + `base64 -d`

## Environment

- **Namespace:** `config`
- **Seeded for you:** file `manifests/app.properties`, and deployment
  `reader` (2 replicas) stuck in `CreateContainerConfigError` — it
  references a ConfigMap that does not exist yet.
- **Output dir:** `~/cka-labs-out/03/`
- **Start here:** `make lab-03`

## Tasks

1. Deployment `reader` in `config` is not starting. Investigate with
   `kubectl describe pod` / `kubectl get pods` (hint: a referenced ConfigMap
   is missing). Fix it **without editing the deployment**: create ConfigMap
   `app-config` with keys `APP_MODE=production` and `LOG_LEVEL=info`. Watch
   the pods become Ready.
2. Create ConfigMap `app-props` from the file
   `labs/03-configmaps-secrets/manifests/app.properties`.
3. Create generic Secret `db-creds` with `username=admin` and
   `password=S3cr3t!`.
4. Generate a self-signed certificate for CN `web.example.com` with
   `openssl` and create TLS secret `web-tls` from the cert/key pair.
5. Create docker-registry secret `regcred` for server `registry.example.com`,
   username `bob`, password `pass`, email `bob@example.com`.
6. Create pod `env-pod` (busybox:1.36, `sleep 3600`) with env var `MODE`
   from `configMapKeyRef` `app-config`/`APP_MODE` and `DB_PASSWORD` from
   `secretKeyRef` `db-creds`/`password`.
7. Create pod `vol-pod` (busybox:1.36, `sleep 3600`) mounting ConfigMap
   `app-props` read-only at `/etc/props` and Secret `db-creds` at
   `/etc/creds`.
8. Change `LOG_LEVEL` to `debug` in ConfigMap `app-config`, then run
   `kubectl rollout restart deployment reader` so the env vars are picked
   up (env vars are only injected at container start!).
9. Create immutable ConfigMap `static-config` with key `version=1` and
   `immutable: true`.
10. Decode the `password` value of secret `db-creds` using `-o jsonpath`
    piped to `base64 -d` and save it to `~/cka-labs-out/03/password.txt`.

## Verify

```bash
make verify-03
```

## Clean up

```bash
make teardown-03
```

## Docs

- https://kubernetes.io/docs/concepts/configuration/configmap/
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/
- https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/
