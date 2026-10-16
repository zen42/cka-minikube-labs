# Lab 15 – HPA & Resource Limits

**Domain:** Workloads & Scheduling (15%) · **Builds on:** Lab 14

Autoscaling and resource governance: `kubectl top`, HorizontalPodAutoscaler
(v1 + v2), requests/limits, QoS classes, LimitRange, ResourceQuota.

## Objectives

- `kubectl top nodes|pods` (metrics-server)
- `kubectl autoscale` + a load generator; HPA v2 memory metrics + behavior
- requests/limits → Guaranteed/Burstable/BestEffort QoS
- `LimitRange` defaults, `ResourceQuota` accounting

## Environment

- **Namespace:** `autoscale`.
- **Output dir:** `~/cka-labs-out/15/`
- **Start here:** `make lab-15`
- metrics-server (addon) scrapes every ~60s — after starting the load
  generator, expect the HPA to react within ~2–4 minutes, not instantly.
- The quota in task 8 counts `requests.cpu` — any pod created after it
  must specify cpu requests (the LimitRange from task 7 supplies them).

## Tasks

1. Save `kubectl top nodes` to `~/cka-labs-out/15/top-nodes.txt`.
2. Create deployment `php-apache` (image `registry.k8s.io/hpa-example`,
   port 80, requests cpu `200m`, limits cpu `500m`, 1 replica) and expose
   it as service `php-apache` port 80.
3. `kubectl autoscale deployment php-apache --cpu-percent=50 --min=1
   --max=5`.
4. Create deployment `load` (2 replicas, busybox) running
   `while true; do wget -q -O- -T 2 http://php-apache; done` — then watch
   the HPA scale `php-apache` above 1 replica.
5. Save `kubectl top pod -n autoscale --containers` to
   `~/cka-labs-out/15/top-pods.txt`.
6. Create three pods demonstrating QoS classes — `qos-guaranteed`
   (requests == limits: cpu `100m`, mem `64Mi`), `qos-burstable`
   (requests only), `qos-besteffort` (no resources) — and write their
   `status.qosClass` to `~/cka-labs-out/15/qos.txt`, one `name=class`
   line each.
7. Create LimitRange `defaults`: default limits cpu `200m`/mem `128Mi`,
   default requests cpu `100m`/mem `64Mi`, max cpu `1`. Then create pod
   `no-resources` (busybox sleep) and confirm the defaults were injected.
8. Create ResourceQuota `team-quota`: `pods: 15`, `requests.cpu: 2`,
   `requests.memory: 2Gi`, `limits.cpu: 4`, `limits.memory: 4Gi`. (The pod
   cap is 15 rather than a tidier 10 — this lab itself runs ~11 pods once
   php-apache scales out, and existing pods count against the quota.)
9. Create deployment `cache` (busybox sleep, requests cpu `50m`/mem
   `32Mi`) and HPA `cache-hpa` (autoscaling/v2): min 1, max 3, memory
   `Utilization` target `70%`, with
   `behavior.scaleDown.stabilizationWindowSeconds: 60`.
10. Scale `load` to 0 and save `kubectl get hpa -n autoscale` to
    `~/cka-labs-out/15/hpa.txt`.

## Verify

Scale-out (task 4) is judged from the HPA's rescale events, so verify still
passes after `load` is scaled down — but it is quickest while `load` is
still running.

```bash
make verify-15     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-15   # from the repo root — or ./teardown.sh in this directory
```

Deletes the namespace and the output dir.

## Docs

- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
- https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/
- https://kubernetes.io/docs/concepts/policy/limit-range/
- https://kubernetes.io/docs/concepts/policy/resource-quotas/
