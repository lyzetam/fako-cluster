# withings-collector — deploy notes

> **STATUS: LIVE (activated 2026-07-20).** Residency verified (Europe app reads the
> US account, userid 48811103), `withings` db created, tailscale authkey minted,
> SOPS bootstrap in place, wired into `apps/staging/kustomization.yaml`, OAuth
> bootstrapped, and both drops confirmed (Postgres `withings_measures` + vault
> `Health/Withings Daily`). The checklist below is retained for rebuild/DR.

Mirrors the `hume-collector` pattern (Tailscale-private receiver + ExternalSecrets
+ two drops: Postgres `withings` db + Obsidian `Health/Withings Daily`). The image
`lzetam/withings-collector:latest` is already built by CI in
`github.com/lyzetam/withings-collector`.

## Why it's a *pull*, not a push

`hume-collector` receives pushes from the HealthBridge iOS app. Withings has no
device that pushes to us — this service authenticates to the **Withings cloud**
via OAuth2 and pulls. The rotating access/refresh token lives in the Postgres
`withings_tokens` row (Withings rotates the refresh token on every refresh, so a
static secret can't hold it). The `client_id`/`client_secret` come from AWS SM
`withings/oauth-app` via `external-secret-oauth.yaml`.

## Activation checklist

1. **Verify residency (GATING).** With the real device + account, open the
   `/authorize` flow once and confirm the Europe Public Cloud app can actually
   read a US-region Withings account. If it can't, the app must be recreated on
   US Cloud (contract-only) — do **not** build further until this is settled.

2. **Create the `withings` database** in the CloudNativePG cluster (same as `hume`):
   ```
   kubectl exec -n postgres postgres-cluster-1 -- psql -U postgres -c "CREATE DATABASE withings OWNER app;"
   ```

3. **Create the Tailscale auth key** in AWS SM at `tailscale/withings-authkey`
   (reusable, non-ephemeral, tagged `tag:k8s`) — see the `tailscale-homelab-expose`
   skill. Confirm `tag:k8s` is in the ACL `tagOwners`.

4. **Confirm IAM.** The ExternalSecrets policy must allow `withings/*` and
   `tailscale/withings-authkey` (it already allows `withings/*` from the account
   setup; add the tailscale path if missing — new policy version, set default).

5. **Add the SOPS `aws-credentials` bootstrap secret** for this namespace, exactly
   like `apps/staging/hume-collector/aws-credentials-secret.yaml` (same AWS creds,
   `namespace: withings-collector`), re-encrypted with the cluster age key.

6. **Wire it into Flux:** create `apps/staging/withings-collector/kustomization.yaml`
   (references `../../base/withings-collector` + the SOPS secret) and uncomment
   `- withings-collector` in `apps/staging/kustomization.yaml`. Then:
   ```
   flux reconcile kustomization apps --with-source
   ```

7. **One-time OAuth bootstrap:** open
   `https://withings-collector.<tailnet>.ts.net/authorize` in a browser logged
   into the real Withings account, grant access. The `/callback` seeds
   `withings_tokens`; the CronJob keeps it fresh thereafter.

8. **Verify the two drops:** a row count in `withings.withings_measures` and a
   file at `Health/Withings Daily/<date>.md` in the vault.
