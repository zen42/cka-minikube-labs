#!/usr/bin/env bash
# Lab 14 verify — one check per task.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner

pod_node() {
    k -n sched get pod "$1" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true
}

# Task 1 — m02 labeled
check_jsonpath "cka-labs-m02 has disktype=ssd" \
    node/cka-labs-m02 '{.metadata.labels.disktype}' 'ssd'

# Task 2 — ssd-pod on m02
check_jsonpath "ssd-pod is Running" \
    pod/ssd-pod '{.status.phase}' 'Running' -n sched
check_eq "ssd-pod landed on m02" "$(pod_node ssd-pod)" "cka-labs-m02"

# Task 3 — affinity spec + lands on the only eligible node
check_jsonpath "affinity-pod required key is disktype" \
    pod/affinity-pod \
    '{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key}' \
    'disktype' -n sched
check "affinity-pod has a preferred term" \
    bash -c "kubectl --context $KUBE_CONTEXT -n sched get pod affinity-pod \
        -o jsonpath='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}' \
        2>/dev/null | grep -q cka-labs-m03"
check_eq "affinity-pod landed on m02" "$(pod_node affinity-pod)" \
    "cka-labs-m02"

# Task 4 — spread: 3 running pods on 3 distinct nodes
_nodes="$(k -n sched get pods -l app=spread \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' \
    2>/dev/null | grep -v '^$' | sort -u | wc -l)"
check_eq "spread pods on 3 distinct nodes" "$_nodes" "3"
_running="$(k -n sched get pods -l app=spread \
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.metadata.name}{"\n"}{end}' \
    2>/dev/null | grep -c . || true)"
check_eq "all 3 spread replicas Running" "$_running" "3"

# Task 5 — buddy co-located with ssd-pod
check "buddy requires affinity to app=ssd" \
    bash -c "kubectl --context $KUBE_CONTEXT -n sched get pod buddy \
        -o jsonpath='{.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchLabels.app}' \
        2>/dev/null | grep -qx ssd"
check_eq "buddy is on ssd-pod's node" "$(pod_node buddy)" \
    "$(pod_node ssd-pod)"

# Task 6 — taint on m03
check_jsonpath "cka-labs-m03 tainted dedicated:NoSchedule" \
    node/cka-labs-m03 '{.spec.taints[?(@.key=="dedicated")].effect}' \
    'NoSchedule'

# Task 7 — gpu-job on m03
check_jsonpath "gpu-job is Running" \
    pod/gpu-job '{.status.phase}' 'Running' -n sched
check_eq "gpu-job landed on m03" "$(pod_node gpu-job)" "cka-labs-m03"

# Task 8 — no-toleration Pending + Unschedulable
check_jsonpath "no-toleration is Pending" \
    pod/no-toleration '{.status.phase}' 'Pending' -n sched
check_jsonpath "no-toleration is Unschedulable" \
    pod/no-toleration \
    '{.status.conditions[?(@.type=="PodScheduled")].reason}' \
    'Unschedulable' -n sched

# Task 9 — tier-spread spec + balanced placement
check_jsonpath "tier-spread maxSkew is 1" \
    deploy/tier-spread \
    '{.spec.template.spec.topologySpreadConstraints[0].maxSkew}' '1' -n sched
check_jsonpath "tier-spread honors node taints" \
    deploy/tier-spread \
    '{.spec.template.spec.topologySpreadConstraints[0].nodeTaintsPolicy}' \
    'Honor' -n sched
_counts="$(k -n sched get pods -l app=tier-spread \
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.spec.nodeName}{"\n"}{end}' \
    2>/dev/null | grep -v '^$' | sort | uniq -c | awk '{print $1}' \
    | sort -n)"
_total="$(awk '{s+=$1} END {print s+0}' <<<"$_counts")"
_min="$(head -1 <<<"$_counts")"; _max="$(tail -1 <<<"$_counts")"
if [[ -n "$_counts" ]]; then _skew=$(( _max - _min )); else _skew=99; fi
check_eq "6 tier-spread pods Running" "$_total" "6"
check "tier-spread skew <= 1" test "$_skew" -le 1

# Task 10 — pinned on the control plane
check_eq "pinned is on cka-labs" "$(pod_node pinned)" "cka-labs"

# Task 11 — priority
check_jsonpath "high-prio value is 100000" \
    priorityclass/high-prio '{.value}' '100000'
check_jsonpath "important got priority 100000" \
    pod/important '{.spec.priority}' '100000' -n sched

# Task 12 — nodes.txt captured the cordon
check_file_contains "nodes.txt shows SchedulingDisabled" \
    "$OUT_DIR/nodes.txt" 'SchedulingDisabled'

# Task 13 — m02 uncordoned again
_uns="$(k get node cka-labs-m02 -o jsonpath='{.spec.unschedulable}' \
    2>/dev/null || true)"
check "cka-labs-m02 is schedulable again" \
    test -z "$_uns" -o "$_uns" = "false"

finish_checks
