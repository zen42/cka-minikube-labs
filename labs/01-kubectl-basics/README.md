# Lab 01 – kubectl Basics

**Domain:** All (foundation) · **Builds on:** Lab 00

The core `kubectl` verbs the whole exam is built on: create, get, describe,
explain, apply, patch, edit, label, annotate, and output formatting.

## Objectives

- `kubectl create/apply/delete`, `--dry-run=client -o yaml`
- `kubectl explain`, `api-resources`
- `-o jsonpath`, `-o custom-columns`, `--sort-by`
- `kubectl label`, `annotate`, `patch`, `edit`

## Environment

- **Namespaces:** `basics` (your working ns), `cleanup-me` (seeded with a
  leftover deployment `old-app` for you to delete).
- **Output dir:** `~/cka-labs-out/01/`
- **Start here:** `make lab-01`

## Tasks

1. Create a namespace named `basics`.
2. Using `kubectl explain`, find the full field path of a Pod's restart
   policy and write it to `~/cka-labs-out/01/restart-policy.txt`
   (e.g. `pod.spec.restartPolicy`).
3. Generate a Pod manifest without creating it:
   `kubectl run nginx-pod --image=nginx:1.27 -n basics --dry-run=client -o yaml`.
   Save it to `~/cka-labs-out/01/pod.yaml`, add the label `tier=web` to the
   manifest, then apply it.
4. Create deployment `web` in `basics` with image `nginx:1.27` and
   2 replicas.
5. Label deployment `web` with `app.kubernetes.io/part-of=shop` and annotate
   it with `owner=platform-team`.
6. Use `kubectl patch` to scale deployment `web` to 3 replicas.
7. Set `spec.revisionHistoryLimit` of deployment `web` to `5`
   (`kubectl edit` or `kubectl patch`).
8. Using `-o jsonpath`, write the ClusterIP of service `kubernetes` in
   namespace `default` to `~/cka-labs-out/01/kubernetes-svc-ip.txt`.
9. Using `-o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName` and
   `--sort-by=.metadata.name`, write the list of pods in `kube-system` to
   `~/cka-labs-out/01/kube-system-pods.txt`.
10. Write the names of all namespaced API resources in API group `apps`
    (`kubectl api-resources --namespaced=true --api-group=apps -o name`) to
    `~/cka-labs-out/01/apps-resources.txt`.
11. Delete deployment `old-app` in namespace `cleanup-me`, then delete the
    `cleanup-me` namespace itself.
12. Save `kubectl get all -n basics -o wide` to
    `~/cka-labs-out/01/basics-all.txt`.

## Verify

```bash
make verify-01     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-01   # from the repo root — or ./teardown.sh in this directory
```

## Docs

- https://kubernetes.io/docs/reference/kubectl/
- https://kubernetes.io/docs/reference/kubectl/quick-reference/
- https://kubernetes.io/docs/reference/kubectl/jsonpath/
- https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
