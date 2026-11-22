# AI Content Studio GitOps deployment

This is the read-only browser/search surface for the S3-backed content inbox.
It does not analyze, render, publish, or write media. The processor in
`claude-social-media/reel-studio` owns Twelve Labs calls and sidecar writes.

## Network exposure

The dashboard is intended for private network access through the cluster's
internal ingress. Keep WAN port-forwarding disabled and retain Supabase
authentication at the application layer. Deployment-specific addresses and
routing details belong in private infrastructure notes, not this repository.

Deployment sequence:

1. Merge `ai-content-studio`; GitHub Actions publishes
   `lzetam/ai-content-studio:sha-<commit>`.
2. Replace `sha-REPLACE_AFTER_CI` in `deployment.yaml` with that exact tag.
3. Review and merge the GitOps change, then enable
   `ai-content-studio` in `apps/staging/kustomization.yaml`.

The image is intentionally pinned instead of using `latest`. Roll back by
reverting the image-tag Git change; S3 sidecars are durable and are not
deleted by this workload.

## Live handoff — 2026-09-28

The dashboard rollout is healthy and currently runs app commit `96dcebe`. The S3 catalog snapshot
is 736 source videos, 15 complete analyses, 721 pending, 104 scene segments, 14 embeddings, and 0
transcripts; the count may grow while the separate NAS→S3 sync Job is running. This workload only
reads persisted sidecars. A separate four-shard Twelve Labs backfill failed and is intentionally
not being retried until it is diagnosed and approved.
