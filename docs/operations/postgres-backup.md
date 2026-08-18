# Postgres backup — two tiers

The shared CloudNativePG cluster (`postgres-cluster` in namespace `postgres`) is
backed up twice, by two independent CronJobs.

| | `postgres-backup` | `postgres-backup-s3` |
|---|---|---|
| when | 02:00 cluster-local | 05:00 cluster-local |
| what | `pg_dump -Fc` per database, `pg_dumpall`, roles, config | copies that directory to S3 |
| where | UGREEN NAS over NFS (`postgres-backup` PVC, `nfs-backup`) | `s3://fako-cluster-postgres-backups/postgres/YYYY/MM/<stamp>/` |
| keeps | 30 days | 30d Standard → Glacier IR, expires at 365d |
| manifest | `apps/base/postgres-cluster/backup-schedule.yaml` | `apps/base/postgres-cluster/backup-s3-cronjob.yaml` |

The S3 job never touches Postgres. It archives what the 02:00 job already wrote,
mounting the backup PVC **read-only**, so it adds no database load and cannot
damage the local copy it is reading.

## The COMPLETE sentinel

`postgres-backup` writes an empty `COMPLETE` file into the backup directory as
its **last** action. `postgres-backup-s3` refuses to upload any directory that
lacks it.

This is the load-bearing safety property, not a nicety. Without it the archive
job cannot distinguish a finished backup from:

- one that died partway through its 17-database loop (leaving a handful of
  perfectly valid `.dump` files), or
- one that is **still being written right now** — the dump took 46m28s on
  2026-08-18 and grows with the data.

Neither case is detectable from the dump files themselves, because a
half-written `.dump` still begins with a valid `PGDMP` magic header. Both would
otherwise have uploaded a partial backup and exited 0.

**If you change the dump script, keep `touch "${BACKUP_PATH}/COMPLETE"` as the
final step.** Moving it earlier silently re-opens both holes.

## Restoring

The dumps are custom-format, so `pg_restore` can select individual databases.
`postgres-recovery` (see `apps/base/postgres-recovery/`) exists to restore into a
scratch instance rather than over production.

```bash
# list what is archived
aws s3 ls s3://fako-cluster-postgres-backups/postgres/ --recursive | tail -30

# pull one night
aws s3 cp s3://fako-cluster-postgres-backups/postgres/2026/08/20260818_020000/ ./restore/ --recursive

# inspect before restoring — this is the real integrity check the archive job
# cannot perform (pg_restore is absent from the amazon/aws-cli image)
pg_restore -l ./restore/oura.dump | head
```

Objects older than 30 days are in Glacier Instant Retrieval — still millisecond
access, no thaw needed. Deep Archive was deliberately not used: a 12-hour
retrieval is useless during a restore.

## AWS resources (created out-of-band — recreate with these)

Nothing in this repo provisions AWS itself. Recorded here so the disaster
recovery path is reproducible rather than folklore.

```bash
BUCKET=fako-cluster-postgres-backups
aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration '{
  "Rules":[{"ID":"postgres-archive","Status":"Enabled","Filter":{"Prefix":"postgres/"},
    "Transitions":[{"Days":30,"StorageClass":"GLACIER_IR"}],
    "Expiration":{"Days":365},
    "NoncurrentVersionExpiration":{"NoncurrentDays":30},
    "AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7}}]}'

aws iam create-user --user-name fako-postgres-backup
aws iam put-user-policy --user-name fako-postgres-backup --policy-name s3-backup-write \
  --policy-document '{"Version":"2012-10-17","Statement":[
    {"Sid":"ListOwnBucket","Effect":"Allow","Action":["s3:ListBucket","s3:GetBucketLocation"],
     "Resource":"arn:aws:s3:::fako-cluster-postgres-backups"},
    {"Sid":"WriteAndReadObjects","Effect":"Allow",
     "Action":["s3:PutObject","s3:GetObject","s3:AbortMultipartUpload","s3:ListMultipartUploadParts"],
     "Resource":"arn:aws:s3:::fako-cluster-postgres-backups/*"}]}'
# then: aws iam create-access-key --user-name fako-postgres-backup
#       -> store as AWS SM secret postgres/s3-backup
#          {access_key_id, secret_access_key, region, bucket}
```

### Why the credential cannot delete

The policy grants **no `s3:DeleteObject`**, and the bucket has versioning on.
A credential lifted out of the cluster can write and read backups but cannot
erase or overwrite the archive — which is the whole point of an off-site copy
that must survive compromise of the primary site. Retention is enforced by the
bucket lifecycle rule, which needs no client delete permission.

`s3:ListBucket` is required, not optional: the archive job re-lists the
destination after upload and fails if the object count does not match.

## Monitoring

`monitoring/configs/base/postgres-backup-alerts/prometheus-rules.yaml` alerts on
either tier failing, and on either going quiet for 36h.

The staleness rules use `kube_cronjob_status_last_successful_time`, **not**
`kube_job_status_completion_time`. Both CronJobs set
`ttlSecondsAfterFinished: 86400`, so Job objects — and their metrics — are
garbage-collected at 24h. A 36h threshold on the Job-level metric can never be
reached; measured max on this cluster was 24.0h across 786 samples. Any future
staleness rule here must use the CronJob-level metric.

Note that kube-state-metrics scrape availability was 74.8% over 6h when these
rules were written, which is why they use `max_over_time` / `absent_over_time`
windows rather than bare `for:` clauses. That KSM instability degrades every
KSM-based alert in the cluster and deserves a separate fix.
