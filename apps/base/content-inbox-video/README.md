# Content inbox video worker

The worker reads the existing offsite S3 copy of the NAS `content_inbox` and
writes adjacent Twelve Labs analysis sidecars. It does not mount the NAS.

Deployment sequence:

1. Merge `claude-social-media`; GitHub Actions publishes
   `lzetam/reel-studio-content-inbox:sha-<commit>`.
2. Replace `sha-REPLACE_AFTER_CI` in `backfill-job.yaml` with that exact tag.
3. Run the read-only coverage repair Job if the S3 copy is incomplete; bump
   its name when rerunning it.
4. Review the processor dry-run inventory, then enable `backfill-job.yaml` in
   the Kustomization for the one-off full analysis run.

The Job is intentionally not a Deployment or CronJob: it is a resumable,
cost-bearing backfill. Keep it out of the standing Kustomization after it
completes, and bump the Job name for any later run.

## Live handoff — 2026-09-28

- `content-inbox-video-sync-002` is still running and copying missing originals from the read-only
  NAS mount to offsite S3.
- `content-inbox-video-restore-002` completed.
- `content-inbox-video-backfill-010` failed all four shards (`0/4`, indexes 0–3). Do not rerun it
  until the failure is diagnosed and the expected Twelve Labs spend is approved.
- Source keys use `year/camera/date/file`. The dashboard's camera-filter issue is in its catalog
  parser, not in this worker.
