#!/usr/bin/env bash
# Lab 05 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

# Task 1 — pi completed and printed pi
check_jsonpath "job pi succeeded" job/pi '{.status.succeeded}' '1' -n batch
check "pi logs contain 3.14" \
    bash -c "kubectl --context $KUBE_CONTEXT -n batch logs job/pi 2>/dev/null \
        | grep -q '3\.14'"

# Task 2 — parallel-echo spec + completion
check_jsonpath "parallel-echo completions is 6" \
    job/parallel-echo '{.spec.completions}' '6' -n batch
check_jsonpath "parallel-echo parallelism is 2" \
    job/parallel-echo '{.spec.parallelism}' '2' -n batch
check_jsonpath "parallel-echo backoffLimit is 3" \
    job/parallel-echo '{.spec.backoffLimit}' '3' -n batch
check_jsonpath "parallel-echo succeeded 6" \
    job/parallel-echo '{.status.succeeded}' '6' -n batch

# Task 3 — must-fail ran to Failed (deleted in task 11; jobs.txt captured it)
check_file_contains "must-fail appeared in jobs.txt" \
    "$OUT_DIR/jobs.txt" 'must-fail'

# Task 4 — deadline exceeded
check_jsonpath "deadline failed with DeadlineExceeded" \
    job/deadline '{.status.conditions[?(@.type=="Failed")].reason}' \
    'DeadlineExceeded' -n batch

# Task 5 — ttl field
check_jsonpath "ttl-job has ttlSecondsAfterFinished 600" \
    job/ttl-job '{.spec.ttlSecondsAfterFinished}' '600' -n batch

# Task 6 — cronjob backup
check_jsonpath "backup schedule is */5" \
    cronjob/backup '{.spec.schedule}' '*/5 * * * *' -n batch
check_jsonpath "backup uses busybox:1.36" \
    cronjob/backup \
    '{.spec.jobTemplate.spec.template.spec.containers[0].image}' \
    'busybox:1.36' -n batch

# Task 7 — cronjob knobs
check_jsonpath "backup concurrencyPolicy Forbid" \
    cronjob/backup '{.spec.concurrencyPolicy}' 'Forbid' -n batch
check_jsonpath "backup successfulJobsHistoryLimit 3" \
    cronjob/backup '{.spec.successfulJobsHistoryLimit}' '3' -n batch
check_jsonpath "backup failedJobsHistoryLimit 1" \
    cronjob/backup '{.spec.failedJobsHistoryLimit}' '1' -n batch
check_jsonpath "backup startingDeadlineSeconds 100" \
    cronjob/backup '{.spec.startingDeadlineSeconds}' '100' -n batch

# Task 8 — manual job from cronjob
check_jsonpath "reporter-manual succeeded" \
    job/reporter-manual '{.status.succeeded}' '1' -n batch
check_jsonpath "reporter-manual uses the cronjob image" \
    job/reporter-manual '{.spec.template.spec.containers[0].image}' \
    'busybox:1.36' -n batch

# Task 9 — reporter suspended
check_jsonpath "reporter is suspended" \
    cronjob/reporter '{.spec.suspend}' 'true' -n batch

# Task 10 — jobs.txt saved
check_file_contains "jobs.txt lists job pi" "$OUT_DIR/jobs.txt" 'pi'

# Task 11 — must-fail gone, pods cascaded
check_absent "job must-fail deleted" job must-fail -n batch
check_fails "no pods labeled job-name=must-fail remain" \
    bash -c "kubectl --context $KUBE_CONTEXT -n batch get pods \
        -l job-name=must-fail --no-headers 2>/dev/null | grep -q ."

finish_checks
