# Lab 05 – Solution

### Task 1

```bash
kubectl create job pi -n batch --image=perl:5.34.0 \
    -- perl -Mbignum=bpi -wle 'print bpi(2000)'
kubectl wait --for=condition=complete job/pi -n batch --timeout=300s
kubectl logs -n batch job/pi | head -1
```

### Task 2

```bash
kubectl apply -n batch -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-echo
spec:
  completions: 6
  parallelism: 2
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "echo hello; sleep 2"]
EOF
kubectl wait --for=condition=complete job/parallel-echo -n batch --timeout=120s
```

### Task 3

```bash
kubectl apply -n batch -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: must-fail
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
EOF
kubectl wait --for=condition=failed job/must-fail -n batch --timeout=180s || true
```

Why: with `restartPolicy: Never` and `backoffLimit: 2` the controller
retries 3 pods total, then marks the Job `Failed` (pod failure policy
aside, this is the exam-relevant path).

### Task 4

```bash
kubectl apply -n batch -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: deadline
spec:
  activeDeadlineSeconds: 20
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["sleep", "300"]
EOF
kubectl wait --for=condition=failed job/deadline -n batch --timeout=60s || true
```

### Task 5

```bash
kubectl apply -n batch -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: ttl-job
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: app
        image: busybox:1.36
        command: ["echo", "done"]
EOF
```

### Task 6

```bash
kubectl create cronjob backup -n batch --image=busybox:1.36 \
    --schedule="*/5 * * * *" -- sh -c 'echo backing up'
```

### Task 7

```bash
kubectl patch cronjob backup -n batch --type=merge -p \
    '{"spec":{"concurrencyPolicy":"Forbid","successfulJobsHistoryLimit":3,
              "failedJobsHistoryLimit":1,"startingDeadlineSeconds":100}}'
```

### Task 8

```bash
kubectl create job reporter-manual --from=cronjob/reporter -n batch
kubectl wait --for=condition=complete job/reporter-manual -n batch --timeout=120s
```

Why: `--from=cronjob/X` stamps out the CronJob's jobTemplate as a one-off
Job — handy for testing a schedule manually.

### Task 9

```bash
kubectl patch cronjob reporter -n batch --type=merge \
    -p '{"spec":{"suspend":true}}'
```

### Task 10

```bash
kubectl get jobs -n batch -o wide > ~/cka-labs-out/05/jobs.txt
```

### Task 11

```bash
kubectl delete job must-fail -n batch
kubectl get pods -n batch -l job-name=must-fail   # gone with the Job
```

Why: the Job is the pods' owner — default cascading delete reaps them.
