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

## 6. Cloudflare Tunnel route
Add `hume-health.landryzetam.net` → the tunnel (same as oura-dashboard's host),
so the phone can POST over HTTPS.

## 7. Point the app
In HealthBridge → Sync tab: Base URL = `https://hume-health.landryzetam.net`,
token = the `hume/ingest-token` value → tap **Send**. Watch `health_samples` fill,
and `Health/Hume Daily` appear in the vault next morning.
```
kubectl -n hume-collector logs deploy/hume-collector
```
