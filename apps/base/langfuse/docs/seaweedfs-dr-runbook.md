# SeaweedFS (langfuse-v2) DR runbook, with security on and Helm hooks off

- **Owner:** Mel. **Reviewer:** Norbert. **Due:** 2026-11-04, alongside LOW item 4 (pre-phase-C backup).
- **Status:** draft runbook, nothing executed. Linked from fako-cluster #454, where it's a merge gate.
- **Source:** Norbert's ruling (b) on #454 in `fako-425-444-411-412-postmerge-review-2026-10-27.md` ("Carl's follow-up rulings", ~9:32 AM ET).
- **Execution:** every DR execution step below needs **Landry's OK**. That covers any kubectl, Flux suspend/resume, PVC restore, values change in prod, or exec into a pod. Merges are by Carl after Norbert's review.

## Why this runbook exists
After #454:
- `global.seaweedfs.enableSecurity: true` is set: JWT on volume and filer read/write, plus gRPC mTLS from cert-manager.
- `upgrade.disableHooks` and `rollback.disableHooks` are `true`.
- `install.disableHooks` is **not** set.

On a fresh or DR install, the chart's post-install Job `langfuse-v2-bucket-hook` therefore still runs. It mounts neither `security.toml` nor client certs, so its `weed shell` (master/filer gRPC) and filer `wget` fail. Flux install remediation (`retries: 3`) then retries the failed install and can loop through uninstall/retry.
- This can't be fixed in this repo. Flux postRenderers don't reach Helm hooks, and the chart's hook Job has no option to mount security config. A fix needs an upstream seaweedfs chart change. That's tracked as optional: owner Mel, no date.

## When to use it
- The `langfuse-v2` HelmRelease has to be **installed** again: the release was uninstalled, the namespace was recreated, or the cluster was rebuilt.
- The SeaweedFS data PVC is lost or corrupt.
- Not needed for an ordinary upgrade or rollback (hooks are off there).

## Facts to have at hand (repo, main + #453/#454)
| Item | Value |
|---|---|
| HelmRelease | `langfuse/langfuse-v2` (`apps/base/langfuse/release-v2.yaml`), chart langfuse 2.1.6, seaweedfs subchart 4.23.0 (alias `s3`) |
| SeaweedFS | Deployment `langfuse-v2-s3-all-in-one`, strategy Recreate, nodeSelector `thinkpad02`, data PVC 20Gi `nfs-csi-v2` (the PVC name needs a live read) |
| Bucket | `langfuse` (single bucket; 19,009 objects copied in phase B) |
| S3 auth | Secret `langfuse-v2-s3` (ESO); S3 on 8333 |
| Security config | Secret `langfuse-v2-s3-security` from ExternalSecret `langfuse-v2-s3-security`, AWS SM key `langfuse/seaweedfs-security` (4 JWT properties, names only) |
| Certs | 7 cert-manager Certificates + 2 Issuers, chart-managed |
| Netpol | `seaweedfs-ingress` allows the hook Job (`batch.kubernetes.io/job-name: langfuse-v2-bucket-hook`) to reach 9333/19333/8888/18888. **Keep this rule** while this runbook relies on the hook (path 2). |

## Before any path
1. Get Landry's OK for the DR action and the window.
2. Suspend the HelmRelease so Flux doesn't run install remediation loops while you work: `flux suspend helmrelease langfuse-v2 -n langfuse` (needs Landry's OK).
3. Confirm the ExternalSecrets `langfuse-v2-s3` and `langfuse-v2-s3-security` are `SecretSynced`. If the AWS SM key is gone, restoring it is a Landry action. Never put values in git.
4. Decide on a path: **1 if the data PVC (or its NFS backing data) survives or can be restored**, otherwise 2, with 3 as the alternative.

## Path 1 (preferred): restore the PVC, skip the hook
The bucket already exists in the restored data, so the hook isn't needed.
1. Restore or re-bind the SeaweedFS data PVC: re-use the surviving NFS-backed PV, or restore its directory from the NAS backup, before the chart creates a fresh empty one (needs Landry's OK).
2. In a **draft PR** (Norbert reviews, Carl merges), add `install.disableHooks: true` to `release-v2.yaml`. Leave `enableSecurity: true`.
3. Resume the HelmRelease. Install runs without the hook. cert-manager issues the Certificates, and SeaweedFS starts with the restored data.
4. Verify (below).
5. Optional follow-up PR: revert `install.disableHooks` only if a later clean install should create buckets again. Otherwise keep it and record the reason in the file.

## Path 2: clean install without data, security off, then on
Use this when the data is gone and an empty bucket is acceptable. Traces and media before the loss are lost; ClickHouse and Postgres are separate.
1. Draft PR: set `global.seaweedfs.enableSecurity: false` (jwtSigning flags can stay; they're ignored without security). Do **not** set `install.disableHooks`. Keep the hook netpol rule.
2. Resume the HelmRelease. Install runs; the post-install hook creates bucket `langfuse` without needing mTLS or JWT.
3. Confirm the hook Job completed and S3 works on 8333 (verify steps 3-4).
4. Second draft PR: set `enableSecurity: true` again. Upgrade runs with hooks disabled. SeaweedFS restarts (Recreate, about 1-2 minutes with no S3) with JWT and mTLS.
5. Verify (below).

## Path 3 (alternative): create the bucket by hand with `weed shell` (**needs Landry's OK**)
Use this when the release installs with security on but the bucket is missing, and path 2's security-off window isn't wanted.
1. Draft PR: set `install.disableHooks: true` (as in path 1). Resume and let install finish without the hook.
2. **Needs Landry's OK (kubectl exec into prod):** exec into the SeaweedFS all-in-one pod, which has `security.toml` and the client certs mounted, and run `weed shell` against the local master/filer (`-master=localhost:9333 -filer=localhost:8888`). Create the bucket (`s3.bucket.create -name langfuse`) and check it (`s3.bucket.list`). Apply any `fs.configure` the chart hook would have done for the bucket; compare with the chart 4.23.0 `post-install-bucket-hook.yaml` before running anything.
3. Verify (below).

## Verify (every path)
1. The 7 Certificates and 2 Issuers in `langfuse` are Ready. The SeaweedFS pod is Ready (`/cluster/status` on 9333 from inside the pod).
2. `helm history langfuse-v2 -n langfuse` shows the install deployed. No looping uninstall/retry.
3. S3 **put and get** through 8333 from the v2 worker, with the existing access keys; the `langfuse` bucket is listed.
4. Langfuse end to end: a new trace is ingested and processed. On path 1, open a trace from before the incident (JWT read path). A batch export works.
5. With security on: an unsigned in-namespace `curl langfuse-v2-s3-all-in-one:8888/buckets/langfuse/` returns 401. From another namespace, 8888 and 9333 time out (#453 netpols).
6. Resume Flux if it's still suspended, and watch the worker and web logs for 24h for `NoSuchBucket`, `AccessDenied`, `jwt` or `x509`.

## Don'ts
- Don't revert #453 alone while #454 is live. The ExternalSecret has `creationPolicy: Owner`, so the mounted Secret would be deleted and SeaweedFS fails on its next restart.
- Don't delete the hook netpol rule while path 2 might still be needed.
- Don't copy JWT keys or S3 keys into git, PRs or tickets. Refer to them by SM key name.
- No force-push on any DR PR.

## Rehearsal (proposed, before 2026-11-04)
A static rehearsal: render path 1 and path 2 values with `helm template` + kubeconform, and check that `install.disableHooks: true` removes the hook from the install manifest. A live rehearsal (scratch namespace or staging) needs Landry's OK.
