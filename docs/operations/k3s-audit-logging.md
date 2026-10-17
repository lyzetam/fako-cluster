# K3s API server audit logging (packet item 4)

Status: draft for review (Norbert) and Landry's OK. Nothing here runs by itself.

## How it's delivered

| Piece | Where | Delivered by |
|---|---|---|
| Audit policy | `docs/operations/k3s-audit/audit-policy.yaml` -> `/etc/rancher/k3s/audit-policy.yaml` on the server | **Host, by hand.** K3s server flags are not in this repo (no ansible, no config in system-upgrade-controller; SUC only swaps the binary). |
| API server flags | `docs/operations/k3s-audit/50-audit.yaml` -> `/etc/rancher/k3s/config.yaml.d/50-audit.yaml` | **Host, by hand.** Needs `systemctl restart k3s` on the server. |
| Shipping to Loki | `monitoring/controllers/base/alloy/alloy-config.yaml` (`local.file_match "k3s_audit"` + `loki.source.file`) | **Flux** (monitoring-controllers). Harmless before the host step: no file, no targets. |

Server node: zz-macbookpro, the only control-plane node. Agents need no change and no restart.

## Who can run it
Someone with a root shell on zz-macbookpro. The bot box has no route or login to it. Whether any engineering agent can reach it without Landry (for example over SSH from zz-mbp-14) is **unknown**; if nobody can, this is a Landry step and goes in the Oct 24 session.

## When
- **Independent of the client CA rotation (item 2).** It touches no certificate, key or TLS path; only the apiserver's audit flags. It can run before, during, or after the rotation.
- **Impact:** one server `systemctl restart k3s`. The API is unavailable for ~30-120 s. Running containers keep running (a k3s restart does not kill containerd shims), so ingress and apps keep serving. Flux and controllers retry. No agent restarts, no pod restarts.
- **Risk:** if the policy or a flag is invalid, the apiserver won't start and the API stays down until the drop-in is removed and k3s restarted again (rollback below, ~2 min). The policy has been loaded and rule-tested offline with `k8s.io/apiserver` v0.34.1's own policy loader (the k3s v1.34.7 line).
- **Earliest safe date:** as soon as Norbert approves the policy, Landry OKs it, and someone with root on the server is available, for example Mon Oct 19 evening, during a quiet hour with a merge freeze of ~15 min. Turning it on **before** Oct 24 is better: it records what happens while the old admin kubeconfig is still on the bot box (Oct 17-24), and it records the rotation itself. As a separate restart, any startup failure is clearly attributable to audit, not to the CA change.
- If it waits for Oct 24: do it as its own restart **before** phase A, verify, then start the rotation.

## Pre-checks (read-only, on zz-macbookpro)
```bash
k3s --version                                             # expect v1.34.7+k3s1
sudo journalctl -u k3s -b --no-pager | grep -m1 'Running kube-apiserver' \
  | grep -o -- '--audit-[a-z-]*=[^ ]*' || echo "AUDIT OFF"
sudo grep -n -i -E 'audit|kube-apiserver-arg' /etc/rancher/k3s/config.yaml || echo "no audit/apiserver args in config.yaml"
sudo ls -la /etc/rancher/k3s/config.yaml.d/ 2>/dev/null || echo "no drop-in dir"
systemctl cat k3s | grep -n -E 'kube-apiserver-arg|audit' || echo "no apiserver args in the unit"
df -h /var/log                                            # want >= 5 GB free
```
**Stop and ask Mel/Norbert if:** audit is already ON; the systemd unit's `ExecStart` sets `--kube-apiserver-arg` (CLI flags and config files interact; don't guess); `config.yaml.d` already holds a file that sets `kube-apiserver-arg` without `+`; or less than 2 GB is free (then set `audit-log-maxbackup=2` in the drop-in).

## Steps (server only)
Copy the two files from this repo onto the server first (e.g. `scp` or `git show origin/main:<path>`). Then:
```bash
# 1. Check the files are the reviewed ones.
sha256sum audit-policy.yaml 50-audit.yaml    # compare with the PR description

# 2. Install them, root-only.
sudo install -o root -g root -m 0600 audit-policy.yaml /etc/rancher/k3s/audit-policy.yaml
sudo install -d -o root -g root -m 0755 /etc/rancher/k3s/config.yaml.d
sudo install -o root -g root -m 0600 50-audit.yaml /etc/rancher/k3s/config.yaml.d/50-audit.yaml
sudo install -d -o root -g root -m 0700 /var/log/kubernetes/audit

# 3. Restart the server (API blip ~30-120 s).
sudo systemctl restart k3s
until sudo k3s kubectl get --raw /readyz >/dev/null 2>&1; do sleep 5; done; echo READY
```

## Verify (counts only; never paste event contents into chat or tickets)
```bash
# Flags in effect:
sudo journalctl -u k3s -b --no-pager | grep -m1 'Running kube-apiserver' | grep -o -- '--audit-[a-z-]*=[^ ]*'
# File exists and grows:
sudo ls -la /var/log/kubernetes/audit/ && sleep 60 && sudo wc -l /var/log/kubernetes/audit/audit.log
# No Secret/ConfigMap/token bodies anywhere (expect 0):
sudo jq -c 'select((.objectRef.resource=="secrets" or .objectRef.resource=="configmaps" or .objectRef.subresource=="token" or .objectRef.resource=="tokenreviews") and (has("requestObject") or has("responseObject")))' \
  /var/log/kubernetes/audit/audit.log | wc -l
# Only RBAC/admission (and later bot-operator) events carry a request body (expect only those groups):
sudo jq -r 'select(has("requestObject")) | .objectRef.apiGroup' /var/log/kubernetes/audit/audit.log | sort | uniq -c
# No RequestReceived stage (expect 0):
sudo jq -c 'select(.stage=="RequestReceived")' /var/log/kubernetes/audit/audit.log | wc -l
```
After ~1 hour, measure volume and project a day: `sudo du -h /var/log/kubernetes/audit/` and the line count. Report MB/hour to Mel. If it's over ~100 MB/hour, Mel tightens the noise rules in a follow-up PR (the top talkers: `jq -r '.user.username' audit.log | sort | uniq -c | sort -rn | head`).

In Loki (Grafana Explore), once the Alloy change is merged:
```logql
sum(count_over_time({job="k3s-audit"}[5m]))
# Secret reads in flux-system by anyone except Flux itself (should be 0; any hit is an incident per Carl):
{job="k3s-audit"} | json | objectRef_namespace="flux-system" | objectRef_resource="secrets"
  | user_username!~"system:serviceaccount:flux-system:.*"
```

## Rollback
```bash
sudo rm /etc/rancher/k3s/config.yaml.d/50-audit.yaml
sudo systemctl restart k3s
```
The policy file and the logs can stay; without the flags nothing reads or writes them.

## Sizing
`audit-log-maxsize=100` (MB per file), `maxbackup=5`, `maxage=7` (days): at most ~600 MB on the server's disk. Loki keeps 30 days (`retention_period: 720h`, 100Gi PVC). The real event rate is unknown until measured; the policy drops the known high-volume sources (health probes, leases, events, node heartbeats, system-component reads, Flux's per-minute server-side-apply dry runs).

## What the policy records
Rule-tested cases (all as intended):
- Admin get/list/create on Secrets, ConfigMaps (any namespace, including flux-system): **Metadata**.
- TokenRequest, TokenReview, SubjectAccessReview, CSR: **Metadata** (bodies hold tokens/keys).
- exec, attach, port-forward, proxy, pods/log: **Metadata** (stream contents never).
- Admin or Flux create/patch/delete on RBAC or admission policies: **Request** (body kept).
- Future `bot-ops:bot-operator` writes: **Request**; its reads: Metadata.
- Workload writes by humans or bots: **Metadata** (pod templates may carry inline env values).
- Flux patch (SSA dry runs) and Flux reads of non-Secret objects: **None**. Flux reads of Secrets and Flux create/delete (prune): **Metadata**.
- Kubelet node/pod status, leases, events, health URLs, system-component reads of non-Secrets: **None**. System components reading Secrets: **Metadata**.

Known gaps (accepted): Flux SSA patches are not audited, so a stolen Flux controller token used only for `patch` would not show up; reading the token itself (a Secret in flux-system) is recorded. Workload write bodies are not kept.
