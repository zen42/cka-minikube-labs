# Lab 23 – Troubleshooting Nodes

**Domain:** Troubleshooting (30%) · **Builds on:** Lab 22

A 3-node cluster where two workers are deliberately broken: one node's
kubelet is stopped (NotReady), the other is cordoned *and* tainted.
Diagnose from the API, fix on the node, and finish with a clean
drain/uncordon maintenance cycle.

## Objectives

- Node `Conditions` (Ready, Pressure), `kubectl describe node`
- kubelet as a systemd unit: `status`, `journalctl -u`, `start`
- Scheduling blockers: cordon (`spec.unschedulable`) vs taints
- `kubectl top nodes`, Allocated resources, node-scoped events
- `drain`/`uncordon` as a maintenance ritual

## Environment

- **Namespace:** `ts-nodes`. **Nodes:** 3 (`cka-labs`,
  `cka-labs-m02`, `cka-labs-m03`) — setup adds workers as needed.
- **Output dir:** `~/cka-labs-out/23/`
- **Start here:** `make lab-23`
- Node access: `minikube -p cka-labs ssh -n <node>` (sudo is
  passwordless).
- Multi-node needs `fs.inotify.max_user_instances >= 1024` on the
  host; `check-env.sh` tells you if yours is too low.

## Tasks

1. Survey: save `kubectl get nodes -o wide` to `nodes.txt` and
   `kubectl describe node cka-labs-m03` to `describe-m03.txt`. Write
   the name of the node that is *not* Ready to `notready-node.txt`.
2. SSH into the broken node (`minikube -p cka-labs ssh -n
   cka-labs-m03`), save `systemctl status kubelet` to
   `kubelet-status.txt` and the last 50 `journalctl -u kubelet` lines
   to `kubelet-journal.txt`, then fix it.
3. Wait until the `node-app` deployment (pinned to m03 via
   nodeSelector) has its replicas running.
4. Make `cka-labs-m02` schedulable again.
5. Remove the remaining scheduling blocker on `cka-labs-m02` (a taint).
6. Save `kubectl get events --field-selector
   involvedObject.kind=Node -A` to `node-events.txt`.
7. Save `kubectl top nodes` to `top-nodes.txt` and the *Allocated
   resources* section of `kubectl describe node cka-labs` to
   `alloc.txt`.
8. Maintenance drill on m03: drain it (`--ignore-daemonsets
   --delete-emptydir-data`), save `kubectl get nodes` to
   `drained.txt`, then uncordon it.
9. Save the node's Ready *condition object*
   (`kubectl get node cka-labs-m03 -o
   jsonpath='{.status.conditions[?(@.type=="Ready")]}'`) to
   `m03-ready.txt`.

## Verify

```bash
make verify-23
```

## Clean up

```bash
make teardown-23
```

Restarts kubelet everywhere, uncordons all nodes, removes the taint,
deletes the namespace and the output dir. Worker nodes stay.

## Docs

- https://kubernetes.io/docs/tasks/debug/debug-cluster/
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- https://kubernetes.io/docs/concepts/architecture/nodes/#condition
