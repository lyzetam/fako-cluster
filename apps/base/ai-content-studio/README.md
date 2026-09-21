# AI Content Studio GitOps deployment

This is the read-only browser/search surface for the S3-backed content inbox.
It does not analyze, render, publish, or write media. The processor in
`claude-social-media/reel-studio` owns Twelve Labs calls and sidecar writes.

## Network exposure

The dashboard is LAN-only. `content.landryzetam.net` is a DNS-only Cloudflare
A record pointing at the cluster's Traefik address (`10.85.30.214`); Traefik
terminates TLS and routes to the ClusterIP service. The hostname is not served
by the shared Cloudflare Tunnel. Keep WAN port-forwarding disabled for the
Traefik address and retain Supabase authentication at the application layer.

Deployment sequence:

1. Merge `ai-content-studio`; GitHub Actions publishes
   `lzetam/ai-content-studio:sha-<commit>`.
2. Replace `sha-REPLACE_AFTER_CI` in `deployment.yaml` with that exact tag.
3. Review and merge the GitOps change, then enable
   `ai-content-studio` in `apps/staging/kustomization.yaml`.

The image is intentionally pinned instead of using `latest`. Roll back by
reverting the image-tag Git change; S3 sidecars are durable and are not
deleted by this workload.
