#!/usr/bin/env bash
# Lab 25 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"
CP="$(control_plane_node)"

# Task 1 — which control-plane component is broken? The mirror pod
# flaps between CrashLoopBackOff and Running during restarts — wait
# until the crash state is actually visible before snapshotting.
wait_for "broken component visible in kube-system" 120 \
    bash -c "kubectl --context $KUBE_CONTEXT get pods -n kube-system \
        --no-headers 2>/dev/null \
        | grep -qE 'kube-scheduler.*(CrashLoopBackOff|Error|Init)'"
k get pods -n kube-system > "$OUT_DIR/kube-system-pods.txt"
grep -E 'CrashLoopBackOff|Error|Init|ImagePull' \
    "$OUT_DIR/kube-system-pods.txt" | head -1 | awk '{print $1}' \
    | sed "s/-$CP\$//" > "$OUT_DIR/broken-component.txt" || true

# Task 2 — logs: why is it failing? The mirror pod's container index
# resets as kubelet recreates it, so --previous may not exist yet —
# retry until a captured log actually fingers the bad config path.
wait_for "scheduler crash log captured" 180 \
    bash -c "{ kubectl --context $KUBE_CONTEXT -n kube-system logs \
        kube-scheduler-$CP --previous 2>/dev/null \
        || kubectl --context $KUBE_CONTEXT -n kube-system logs \
            kube-scheduler-$CP 2>/dev/null; } \
        | tee '$OUT_DIR/scheduler.log' \
        | grep -qE 'scheduler.conf.wrong|no such file'"

# Task 3 — fix the manifest; kubelet restarts the static pod
node_ssh "$CP" \
    "sudo sed -i 's|scheduler.conf.wrong|scheduler.conf|g' \
        /etc/kubernetes/manifests/kube-scheduler.yaml" >/dev/null
wait_for "scheduler Running again" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pod \
        kube-scheduler-$CP -o \
        jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null \
        | grep -q true"
wait_for "stuck deployment scheduled" 180 \
    deploy_available ts-cp stuck

# Task 4 — API server health endpoints
k get --raw /livez?verbose > "$OUT_DIR/livez.txt"
k get --raw /readyz?verbose > "$OUT_DIR/readyz.txt"

# Task 5 — static pod path + manifests
node_ssh "$CP" \
    "sudo grep staticPodPath /var/lib/kubelet/config.yaml" \
    > "$OUT_DIR/static-pod-path.txt"
node_ssh "$CP" "sudo ls /etc/kubernetes/manifests/" \
    > "$OUT_DIR/static-manifests.txt"

# Task 6 — the apiserver container via crictl
node_ssh "$CP" "sudo crictl ps --name kube-apiserver" \
    > "$OUT_DIR/apiserver-ps.txt"
cid="$(node_ssh "$CP" \
    "sudo crictl ps --name kube-apiserver -q | head -1" | tr -d '[:space:]')"
node_ssh "$CP" "sudo crictl logs --tail 20 $cid" \
    > "$OUT_DIR/apiserver-log.txt" 2>&1 || true

# Task 7 — apiserver serving cert
node_ssh "$CP" \
    "sudo openssl x509 -in /var/lib/minikube/certs/apiserver.crt \
        -noout -subject -dates" > "$OUT_DIR/apiserver-cert.txt"
node_ssh "$CP" \
    "sudo openssl x509 -in /var/lib/minikube/certs/apiserver.crt \
        -noout -ext subjectAltName" > "$OUT_DIR/apiserver-san.txt"

# Task 8 — who owns a mirror pod?
k -n kube-system get pod "kube-apiserver-$CP" \
    -o jsonpath='{.metadata.ownerReferences[0].kind}' \
    > "$OUT_DIR/apiserver-owner.txt"

# Task 9 — controller-manager liveness
k -n kube-system describe pod "kube-controller-manager-$CP" \
    | grep -A3 'Liveness' > "$OUT_DIR/cm-liveness.txt"

# Task 10 — kubelet's view of the scheduler mess
node_ssh "$CP" \
    "sudo journalctl -u kubelet --no-pager | grep -i scheduler \
        | tail -20" > "$OUT_DIR/kubelet-scheduler.txt" || true

info "lab 25 solved"
