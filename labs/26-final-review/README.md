# Lab 26 – Final Review (Timed Mock)

**Domain:** All five (mixed) · **Builds on:** Lab 25

Twelve tasks across every CKA domain, in one namespace, against the
clock — treat it as a mock exam. Suggested time: **60 minutes**.

## Objectives

- Deployments, services (ClusterIP + NodePort), Ingress, HPA
- ConfigMap/Secret injection, PV/PVC storage, RBAC
- NetworkPolicy, CronJobs, node scheduling, etcd snapshots

## Environment

- **Namespace:** `final` — seeded with a broken deployment `legacy`
  and an Available manual PersistentVolume `final-pv`
  (hostPath `/data/final`, 500Mi, RWO).
- **Output dir:** `~/cka-labs-out/26/`
- **Start here:** `make lab-26`

## Tasks

1. Create deployment `shop` (image `nginx:1.27`, 3 replicas) with
   requests `cpu: 50m`, `memory: 64Mi` and limits `cpu: 200m`,
   `memory: 128Mi`. The pods must carry label `tier=frontend`.
2. Expose `shop` as ClusterIP service `shop-svc` on port 80, and as
   NodePort service `shop-np` on nodePort `30080`.
3. Create Ingress `shop-ing` (class `nginx`) routing host
   `shop.final.local` to `shop-svc`. Verify it serves the nginx
   welcome page through the ingress controller.
4. Create an HPA for `shop`: min 2, max 5, target 60% CPU.
5. Create ConfigMap `shop-config` (`THEME=dark`) and Secret
   `shop-secret` (`API_KEY=abc123`); inject both into `shop` via
   `envFrom`.
6. Create PVC `final-pvc` that binds the existing `final-pv`, and a
   pod `writer` (busybox) that mounts it at `/data` and writes its
   hostname to `/data/out.txt`.
7. Create ServiceAccount `deployer`, Role `deploy-manager` (verbs
   `get,list,create,update,patch` on `deployments`) and bind them.
   Prove `deployer` can create deployments but not delete them.
8. Create NetworkPolicy `shop-allow-ingress-only`: ingress to
   `tier=frontend` pods only from the `ingress-nginx` namespace
   (label `kubernetes.io/metadata.name`) and from pods labelled
   `access=shop`, on port 80.
9. Create CronJob `report` running `date` (busybox) on schedule
   `*/10 * * * *` with `successfulJobsHistoryLimit: 2`. Run it once
   manually as job `report-manual` and confirm completion.
10. Fix deployment `legacy` — it should run `httpd:2.4` and become
    available.
11. Label node `cka-labs` with `zone=a` and patch `shop` with a
    `nodeSelector` for it; confirm the rollout succeeds.
12. On the node, save an etcd snapshot to
    `/var/lib/minikube/etcd-backup/final.db` and record `etcdutl
    snapshot status` output to `$OUT_DIR/etcd-status.txt`. Finally,
    save `kubectl get all -n final -o wide` to
    `$OUT_DIR/final-state.txt`.

## Verify

```bash
make verify-26
```

## Clean up

```bash
make teardown-26
```

Deletes the namespace, the PV, the node label, the snapshot file and
the output dir.

## Docs

- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
