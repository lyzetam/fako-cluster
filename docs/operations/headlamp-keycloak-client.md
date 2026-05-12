# Headlamp Keycloak Client Setup

One-time manual step to wire `oauth2-proxy` in front of `headlamp.landryzetam.net`. This is the prerequisite for Task 6 in
[../superpowers/plans/2026-05-11-p0-rbac-and-runtime-hardening.md](../superpowers/plans/2026-05-11-p0-rbac-and-runtime-hardening.md).

Pattern mirrors the existing `oura-dashboard` oauth2-proxy setup.

## 1. Create the Keycloak client

Open the Keycloak admin UI at `https://auth.landryzetam.net/` → `master` realm → **Clients** → **Create client**:

| Field | Value |
|---|---|
| Client ID | `headlamp` |
| Client type | OpenID Connect |
| Client authentication | ON |
| Authorization | OFF |
| Standard flow | ON (Authorization Code) |
| Direct access grants | OFF |
| Root URL | `https://headlamp.landryzetam.net` |
| Valid redirect URIs | `https://headlamp.landryzetam.net/oauth2/callback` |
| Web origins | `https://headlamp.landryzetam.net` |

After saving, open the **Credentials** tab and copy the **Client secret**.

## 2. Generate a cookie secret

```bash
python3 -c 'import os, base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

## 3. Store in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "headlamp/oauth2-proxy" \
  --secret-string "$(cat <<EOF
{
  "client-id": "headlamp",
  "client-secret": "<paste-from-keycloak>",
  "cookie-secret": "<paste-from-step-2>"
}
EOF
)"
```

If the secret already exists, use `put-secret-value` instead (the AWS MCP server has no `secrets_update` tool — see fako-cluster MEMORY.md):

```bash
aws secretsmanager put-secret-value \
  --secret-id "headlamp/oauth2-proxy" \
  --secret-string "$(cat <<EOF
{ ... }
EOF
)"
```

## 4. Verify

```bash
aws secretsmanager get-secret-value --secret-id headlamp/oauth2-proxy \
  --query SecretString --output text | jq 'has("client-id") and has("client-secret") and has("cookie-secret")'
```

Expected: `true`. Task 6 of the P0 plan can now proceed.
