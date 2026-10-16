# Lab 22 – Troubleshooting Pods

**Domain:** Troubleshooting (30%) · **Builds on:** Lab 21

Setup seeds a namespace full of broken workloads. For each one: find
*why* it fails (`get`, `describe`, `logs`, `events`), record the
diagnostic artefact the task asks for, then fix it — and prove the fix.

## Objectives

- The pod failure ladder: Pending → CreateContainerConfigError →
  ImagePullBackOff → CrashLoopBackOff → Running-not-Ready
- `describe` lastState (exit codes, OOMKilled), `logs --previous`,
  `-c <container>`, `kubectl wait`, `kubectl get events`
- `kubectl debug` ephemeral containers and node debugging

## Environment

- **Namespace:** `ts-pods` — seeded broken by setup.
- **Output dir:** `~/cka-labs-out/22/`
- **Start here:** `make lab-22`

## Tasks

1. Deployment `img-typo` never becomes available. Find the cause and
   fix it so it runs nginx **1.27**.
2. Pod `crash-app` keeps restarting. Find its exit code
   (`describe` Last State, or `logs --previous`), write the number to
   `~/cka-labs-out/22/crash-exit-code.txt`, then recreate it so it
   stays Running: env `FOO=bar` and a command that exits 3 if `FOO` is
   unset, otherwise `sleep 3600`.
3. Deployment `probe-fail` runs but is never Ready. Fix the probe and
   wait until its replicas are Ready.
4. Pod `oom-app` keeps dying — the kernel OOM-kills it. Write its
   lastState *reason and exit code* to
   `~/cka-labs-out/22/oom-reason.txt`, then recreate it with a memory
   limit of `64Mi` and a bounded workload (`head -c 8M /dev/zero |
   tail -c 1 >/dev/null; sleep 3600`).
5. Pod `pending-app` never schedules. Write the scheduler's failure
   reason to `~/cka-labs-out/22/pending-reason.txt`, then fix the pod
   so it runs.
6. Pod `cm-missing` never starts its container
   (`CreateContainerConfigError`). Make it run — you may not need to
   touch the pod itself: create the ConfigMap the pod references
   (discover its name via `kubectl describe pod cm-missing -n ts-pods`)
   with `MODE=prod`.
7. Pod `quiet` (pause image) can't take a shell. Start a busybox
   ephemeral debug container inside it:
   `kubectl debug quiet -n ts-pods --image=busybox:1.36 --target=quiet
   -- sleep 3600`.
8. Debug the *node*: `kubectl debug node/cka-labs -n default
   --image=busybox:1.36 -- chroot /host cat /etc/hostname` (the debug
   pod lands in your *context* namespace — pin `-n default`), wait for
   the pod to complete,
   save its logs to `~/cka-labs-out/22/node-hostname.txt`, then delete
   the debugger pod.
9. Pod `sidecar-app` has two containers. Save the last 5 log lines of
   container `sidecar` to `~/cka-labs-out/22/sidecar.log`.
10. Save `kubectl get events -n ts-pods --sort-by=.lastTimestamp` to
    `~/cka-labs-out/22/events.txt`, and use `kubectl wait` to prove
    the `probe-fail` pods are Ready.

## Verify

```bash
make verify-22     # from the repo root — or ./verify.sh in this directory
```

## Clean up

```bash
make teardown-22   # from the repo root — or ./teardown.sh in this directory
```

## Docs

- https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container
- https://kubernetes.io/docs/tasks/debug/debug-cluster/kubectl-node-debug/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/
