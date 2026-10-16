# Lab 05 – Jobs & CronJobs

**Domain:** Workloads & Scheduling (15%) · **Builds on:** Lab 04

Run-to-completion workloads: one-shot Jobs, parallel Jobs, failing Jobs,
deadlines, TTL cleanup, and scheduled CronJobs.

## Objectives

- `kubectl create job`, `create job --from=cronjob/...`, `create cronjob`
- `completions`, `parallelism`, `backoffLimit`, `activeDeadlineSeconds`,
  `ttlSecondsAfterFinished`
- Job conditions (Complete/Failed), CronJob `suspend`,
  `concurrencyPolicy`, history limits

## Environment

- **Namespace:** `batch`
- **Seeded for you:** CronJob `reporter` (`* * * * *`, busybox printing
  `date; echo report`) — already producing Job pods every minute.
- **Output dir:** `~/cka-labs-out/05/`
- **Start here:** `make lab-05`

## Tasks

1. Create Job `pi` running image `perl:5.34.0` with command
   `perl -Mbignum=bpi -wle 'print bpi(2000)'`. Wait for it to complete and
   confirm its logs print π.
2. Create Job `parallel-echo` **from a manifest**: busybox:1.36 running
   `sh -c 'echo hello; sleep 2'`, `completions: 6`, `parallelism: 2`,
   `backoffLimit: 3`.
3. Create Job `must-fail`: busybox:1.36 running `sh -c 'exit 1'`,
   `restartPolicy: Never`, `backoffLimit: 2`. Wait for the Job to reach
   `Failed` condition.
4. Create Job `deadline`: busybox:1.36 running `sleep 300` with
   `activeDeadlineSeconds: 20`. Wait for it to fail with reason
   `DeadlineExceeded`.
5. Create Job `ttl-job`: busybox:1.36 running `echo done` with
   `ttlSecondsAfterFinished: 600`.
6. Create CronJob `backup` with schedule `*/5 * * * *`, image
   `busybox:1.36`, command `sh -c 'echo backing up'`
   (`kubectl create cronjob`).
7. On `backup` set: `concurrencyPolicy: Forbid`,
   `successfulJobsHistoryLimit: 3`, `failedJobsHistoryLimit: 1`,
   `startingDeadlineSeconds: 100`.
8. Create a Job manually from a CronJob:
   `kubectl create job reporter-manual --from=cronjob/reporter -n batch`.
9. Suspend CronJob `reporter` so it stops scheduling.
10. Save `kubectl get jobs -n batch -o wide` to
    `~/cka-labs-out/05/jobs.txt`.
11. Delete Job `must-fail` — its pods must be garbage-collected with it.

## Verify

```bash
make verify-05
```

## Clean up

```bash
make teardown-05
```

## Docs

- https://kubernetes.io/docs/concepts/workloads/controllers/job/
- https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
- https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/
