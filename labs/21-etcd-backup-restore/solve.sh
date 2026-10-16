#!/usr/bin/env bash
# Lab 21 solve — non-interactive run of every task in SOLUTION.md.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/common.sh"

lab_banner
mkdir -p "$OUT_DIR"

CP="$(control_plane_node)"
CERTS=/var/lib/minikube/certs/etcd
ETCDCTL="sudo /usr/local/bin/etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=$CERTS/ca.crt \
    --cert=$CERTS/server.crt \
    --key=$CERTS/server.key"
SNAP=/var/lib/minikube/etcd-backup/snapshot.db
MANIFEST=/etc/kubernetes/manifests/etcd.yaml

# Task 1 — endpoint health + member list
node_ssh "$CP" "$ETCDCTL endpoint health" > "$OUT_DIR/endpoint-health.txt"
node_ssh "$CP" "$ETCDCTL member list -w table" > "$OUT_DIR/members.txt"

# Task 2 — snapshot + verify it with etcdutl
node_ssh "$CP" \
    "sudo mkdir -p /var/lib/minikube/etcd-backup \
        && $ETCDCTL snapshot save $SNAP"
node_ssh "$CP" "sudo /usr/local/bin/etcdutl snapshot status $SNAP \
    -w table" > "$OUT_DIR/snapshot-status.txt"

# Task 3 — marker created AFTER the snapshot: it must vanish post-restore
k create configmap after-snapshot -n etcd-lab \
    --from-literal=marker=after \
    --dry-run=client -o yaml | k apply -f - >/dev/null
info "after-snapshot exists now; the restore must erase it"

# Task 4 — restore the snapshot
_name="$(node_ssh "$CP" \
    "sudo grep -o -- '--name=[^[:space:]]*' $MANIFEST | head -1 \
        | cut -d= -f2-" | tr -d '[:space:]')"
_ic="$(node_ssh "$CP" \
    "sudo grep -o -- '--initial-cluster=[^[:space:]]*' $MANIFEST | head -1 \
        | cut -d= -f2-" | tr -d '[:space:]')"
_peer="$(node_ssh "$CP" \
    "sudo grep -o -- '--initial-advertise-peer-urls=[^[:space:]]*' $MANIFEST \
        | head -1 | cut -d= -f2-" | tr -d '[:space:]')"
info "restoring as name=$_name initial-cluster=$_ic peer=$_peer"

node_ssh "$CP" "sudo /usr/local/bin/etcdutl snapshot restore $SNAP \
    --data-dir /var/lib/minikube/etcd-restored \
    --name $_name \
    --initial-cluster $_ic \
    --initial-advertise-peer-urls $_peer"

# stop etcd by moving the static manifest aside, then swap data dirs
node_ssh "$CP" "sudo mv $MANIFEST /tmp/etcd.yaml"
wait_for "etcd container stopped" 120 \
    bash -c "[[ -z \$(minikube -p $MINIKUBE_PROFILE ssh -- \
        'sudo crictl ps --name etcd -q' 2>/dev/null) ]]"
node_ssh "$CP" \
    "sudo mv /var/lib/minikube/etcd /var/lib/minikube/etcd.pre-restore \
        && sudo mv /var/lib/minikube/etcd-restored /var/lib/minikube/etcd \
        && sudo mv /tmp/etcd.yaml $MANIFEST"

# wait for the API (and the etcd pod behind it) to come back
wait_for "apiserver /readyz ok" 180 k get --raw=/readyz
wait_for "etcd pod Ready again" 180 \
    bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pod \
        etcd-$CP -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' \
        2>/dev/null | grep -q True"

# restart the rest of the control plane: their informer/watch caches
# predate the rewound etcd and would keep serving post-snapshot objects
# (the rv went backwards, so they never relist). Fresh processes relist
# from the restored store.
for comp in kube-apiserver kube-controller-manager kube-scheduler; do
    node_ssh "$CP" \
        "sudo crictl stop \$(sudo crictl ps --name $comp -q)" \
        >/dev/null 2>&1 || true
done
wait_for "apiserver /readyz ok (post-restart)" 180 k get --raw=/readyz
for comp in kube-controller-manager kube-scheduler; do
    wait_for "$comp Running again" 180 \
        bash -c "kubectl --context $KUBE_CONTEXT -n kube-system get pod \
            $comp-$CP -o jsonpath='{.status.phase}' 2>/dev/null \
            | grep -q Running"
done

# Task 5 — proof of restore. Wait until even the relisted cache agrees
# the post-snapshot object is gone before recording the listing.
wait_for "after-snapshot rolled back" 90 \
    bash -c "! kubectl --context $KUBE_CONTEXT get cm after-snapshot \
        -n etcd-lab >/dev/null 2>&1"
k get cm -n etcd-lab > "$OUT_DIR/cm-after-restore.txt"
node_ssh "$CP" "$ETCDCTL endpoint status -w table" \
    > "$OUT_DIR/endpoint-status.txt"
if k get cm before-snapshot -n etcd-lab >/dev/null 2>&1 \
    && ! k get cm after-snapshot -n etcd-lab >/dev/null 2>&1; then
    info "restore proven: before-snapshot present, after-snapshot gone"
else
    warn "post-restore state looks wrong — check cm listing"
fi

info "lab 21 solved"
