#!/usr/bin/env bash
# Verify aitower actually recovered after a power-on.
# Read-only: get/describe only. No mutations.
set -uo pipefail

NODE=aitower
IP=10.85.30.58

echo "=== 1. host reachable? ==="
ping -c 2 -t 4 "$IP" >/dev/null 2>&1 && echo "PING OK" || echo "PING FAIL - still down"
nc -z -G 4 "$IP" 22    >/dev/null 2>&1 && echo "SSH  OK" || echo "SSH  FAIL"
nc -z -G 4 "$IP" 10250 >/dev/null 2>&1 && echo "KUBELET OK" || echo "KUBELET FAIL"

echo
echo "=== 2. node status ==="
kubectl get node "$NODE" -o wide

echo
echo "=== 3. conditions (want Ready=True, heartbeat within ~1m) ==="
kubectl describe node "$NODE" | sed -n '/^Conditions:/,/^Addresses:/p'

echo
echo "=== 4. unreachable taints cleared? (want empty) ==="
kubectl get node "$NODE" -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.effect}{"\n"}{end}'

echo
# NOTE: do NOT check .status.allocatable for GPUs here. That field persists
# from the last report the node made before it died, so it reads "2" even while
# the node is unreachable. The heartbeat in check 3 is the field that tells you
# whether the node is actually alive.

echo
echo "=== 6. pods still Pending cluster-wide (want none of the aitower-pinned set) ==="
kubectl get pods -A --field-selector status.phase=Pending -o wide

echo
echo "=== 7. stuck Terminating leftovers on this node ==="
kubectl get pods -A -o wide --field-selector spec.nodeName="$NODE" 2>/dev/null \
  | awk 'NR==1 || $4=="Terminating"' | head -20

echo
echo "=== 8. the workloads that were actually blocked ==="
for ns in sports-bets ollama piper parakeet openwakeword soccer-banter sftp-server langfuse; do
  printf '%-16s ' "$ns"
  kubectl get pods -n "$ns" --no-headers 2>/dev/null \
    | awk '{print $1"("$3")"}' | tr '\n' ' ' || echo "-"
  echo
done

echo
echo "=== 9. flux still healthy ==="
flux get kustomizations 2>/dev/null || kubectl get kustomizations -A
