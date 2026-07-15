# hume-collector — deploy runbook (all steps gated on you)

Mirrors `oura-collector`. Image is built by the **`lyzetam/hume-collector`** code
repo; these manifests are pulled by Flux. **Nothing here deploys until you run the
outward steps below.**

## 1. Build & publish the image
```bash
cd ~/dev/hume-collector
gh repo create lyzetam/hume-collector --private --source=. --push
# add GH secrets DOCKERHUB_USERNAME / DOCKERHUB_TOKEN (from AWS SM dockerhub/credentials)
# push to main → CI builds lzetam/hume-collector:latest
```

## 2. Create the AWS Secrets Manager secrets
- **`hume/ingest-token`** — new. A random string; the token the app sends.
  ```bash
  aws secretsmanager create-secret --name hume/ingest-token \
    --secret-string "$(openssl rand -hex 24)" --region us-east-1
  ```
- **`postgres/app-user`** — already exists (reused).
- **`obsidian/api`** — already exists (reused by oura).

## 3. One-time Postgres database
The receiver writes to database `hume`:
```sql
CREATE DATABASE hume;   -- grant to the app-user role
```
(Or point `DATABASE_NAME` in `configmap.yaml` at an existing DB.)

## 4. SOPS bootstrap secret (needs your age key)
Create `apps/staging/hume-collector/aws-credentials-secret.yaml` for namespace
`hume-collector` — copy oura's and re-encrypt:
```bash
cd ~/dev/fako-cluster/apps/staging
sops -d oura-collector/aws-credentials-secret.yaml \
  | sed 's/namespace: oura-collector/namespace: hume-collector/' \
  | sops -e /dev/stdin > hume-collector/aws-credentials-secret.yaml
```

## 5. Activate & reconcile
Add `- hume-collector` to `apps/staging/kustomization.yaml`, then:
```bash
git add apps/base/hume-collector apps/staging/hume-collector apps/staging/kustomization.yaml
git commit -m "feat(hume): deploy hume-collector receiver + daily report"
git push && flux reconcile kustomization apps --with-source
```

## 6. Cloudflare Tunnel route (the last mile — needs your Cloudflare account)
The receiver is live in-cluster; this exposes it over HTTPS. `cloudflare.yaml`
is written and ready but **not** in `kustomization.yaml` yet (it crashloops
without the credentials secret).

```bash
# create the named tunnel + DNS, then drop its credentials into the namespace
cloudflared tunnel login
cloudflared tunnel create hume-health
cloudflared tunnel route dns hume-health hume-health.landryzetam.net
# store credentials.json as the tunnel-credentials secret (sops or a k8s secret)
kubectl create secret generic tunnel-credentials -n hume-collector \
  --from-file=credentials.json=$HOME/.cloudflared/<TUNNEL_ID>.json --dry-run=client -o yaml \
  | sops -e /dev/stdin > ../../staging/hume-collector/tunnel-credentials.yaml   # then add to overlay
```
Then add `- cloudflare.yaml` to `kustomization.yaml`, commit, push, reconcile.
Alternative: skip Cloudflare and use **Tailscale Serve** on the service — the app
just needs any `https://…` base URL.

## 7. Point the app
In HealthBridge → Sync tab: Base URL = `https://hume-health.landryzetam.net`,
token = the `hume/ingest-token` value → tap **Send**. Watch `health_samples` fill,
and `Health/Hume Daily` appear in the vault next morning.
```
kubectl -n hume-collector logs deploy/hume-collector
```
