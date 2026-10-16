# Lab 04 – Deployments & Rollouts

**Domain:** Workloads & Scheduling (15%) · **Builds on:** Lab 03

The full Deployment lifecycle: scaling, image updates, rollout
history/undo/pause/resume, strategies, and ReplicaSets underneath.

## Objectives

- `kubectl create deployment`, `scale`, `set image`, `set resources`
- `kubectl rollout status/history/undo/pause/resume`
- RollingUpdate vs Recreate strategy; `change-cause` annotations
- `minReadySeconds`, `progressDeadlineSeconds`

## Environment

- **Namespace:** `deploy`
- **Seeded for you:** deployment `api` (nginx:1.26, 2 replicas).
- **Output dir:** `~/cka-labs-out/04/`
- **Start here:** `make lab-04`

## Tasks

1. Create deployment `web` in `deploy` with image `nginx:1.26` and
   3 replicas.
2. Scale `web` to 5 replicas with `kubectl scale`.
3. Update `web` to `nginx:1.27` with `kubectl set image` and record a
   `kubernetes.io/change-cause` annotation `"update to 1.27"`.
4. Save `kubectl rollout history deployment/web -n deploy` to
   `~/cka-labs-out/04/history.txt`.
5. On deployment `api`, set the image to `nginx:1.99-doesnotexist` and
   watch the rollout stall (`ImagePullBackOff`). Recover with
   `kubectl rollout undo deployment/api`.
6. Configure `web`'s update strategy: RollingUpdate with `maxSurge: 1`,
   `maxUnavailable: 0`.
7. `kubectl rollout pause deployment/web`, then update BOTH the image to
   `nginx:1.28` AND the resources (`kubectl set resources deployment web
   --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi`), then
   `rollout resume`. Both changes should land in ONE rollout.
8. `kubectl rollout undo deployment/web --to-revision=2`.
9. Write a manifest `~/cka-labs-out/04/recreate.yaml` for deployment
   `recreate-app` (busybox:1.36, `sleep 3600`, 2 replicas, strategy type
   `Recreate`) and apply it.
10. Set `minReadySeconds: 5` and `progressDeadlineSeconds: 300` on `web`.
11. Write the name of the ReplicaSet that currently owns `web`'s pods
    (the one with `spec.replicas > 0`) to
    `~/cka-labs-out/04/current-rs.txt`.
12. Scale `api` down to 0 replicas.

## Verify

```bash
make verify-04
```

## Clean up

```bash
make teardown-04
```

## Docs

- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/
- https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
