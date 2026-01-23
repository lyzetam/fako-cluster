# Backstage Status - Work in Progress

**Last Updated:** 2026-01-23
**Status:** ⚠️ DISABLED - Awaiting AWS Secret Creation

## What We Accomplished

### 1. Switched from GitHub OAuth to Keycloak OIDC
- ✅ Created Keycloak OIDC client at https://auth.landryzetam.net
- ✅ Configured OIDC authentication in Backstage app-config
- ✅ Created ExternalSecret for Keycloak credentials
- ✅ Disabled guest access (signInPage: oidc)

### 2. Tried RHDH (Red Hat Developer Hub)
- ❌ RHDH had dynamic plugins init container crashes
- ❌ Plugin catalog index packaging issues
- Decision: Reverted to vanilla Backstage for stability

### 3. Reverted to Official Backstage Image
- ✅ Using trusted image: `ghcr.io/backstage/backstage:latest`
- ✅ Vanilla Backstage Helm chart (1.x)
- ✅ All configuration in place and ready

### 4. Created Documentation
- ✅ `KEYCLOAK-SETUP.md` - Complete Keycloak configuration guide
- ✅ `NEXT-STEPS.md` - Deployment instructions and requirements
- ✅ `STATUS.md` - This file

## Why Backstage is Disabled

Backstage pod cannot start because it's missing the Keycloak credentials:

```
Error: secret "backstage-keycloak-secret" not found
```

The ExternalSecret is configured but AWS Secrets Manager doesn't have `/fako/backstage/keycloak-oidc` yet.

## To Re-Enable Backstage

### Step 1: Create AWS Secret

```bash
# Generate secure backend secret
BACKEND_SECRET=$(openssl rand -base64 32)

# Get Keycloak client secret from https://auth.landryzetam.net:
# - Login: admin / Admin#toKbiz-cysze4-wornem!
# - Navigate: Clients → backstage → Credentials tab
# - Copy the "Client Secret" value

# Create the secret
aws secretsmanager create-secret \
  --name "/fako/backstage/keycloak-oidc" \
  --secret-string "{
    \"client_id\": \"backstage\",
    \"client_secret\": \"<PASTE_CLIENT_SECRET_FROM_KEYCLOAK>\",
    \"metadata_url\": \"https://auth.landryzetam.net/realms/master/.well-known/openid-configuration\",
    \"backend_secret\": \"${BACKEND_SECRET}\"
  }"
```

### Step 2: Force ExternalSecret Sync

```bash
kubectl annotate externalsecret backstage-keycloak-secret -n backstage \
  force-sync=$(date +%s) --overwrite
```

### Step 3: Re-enable in Staging

Edit `apps/staging/kustomization.yaml`:
- Uncomment the `- ../base/backstage` line
- Commit and push
- Flux will deploy automatically

### Step 4: Verify Deployment

```bash
kubectl get pods -n backstage
kubectl logs -n backstage -l app.kubernetes.io/name=backstage
```

## Configuration Files

All files are ready and in place:

| File | Purpose | Status |
|------|---------|--------|
| `namespace.yaml` | Backstage namespace | ✅ Ready |
| `repository.yaml` | Helm chart source | ✅ Vanilla Backstage |
| `release.yaml` | HelmRelease config | ✅ OIDC configured |
| `ingress.yaml` | HTTPS routing | ✅ Ready |
| `rbac.yaml` | K8s permissions | ✅ Ready |
| `configmap-app-config.yaml` | App config (unused) | ⚠️ Not used with inline config |
| `secret-store.yaml` | AWS Secrets access | ✅ Ready |
| `external-secret-postgres.yaml` | DB credentials | ✅ Working |
| `external-secret-keycloak.yaml` | OIDC credentials | ⚠️ Waiting for AWS secret |
| `external-secret-github.yaml` | Deleted (switched to Keycloak) | ❌ Removed |
| `kustomization.yaml` | Resource list | ✅ Ready |

## Keycloak Client Configuration

**Client Name:** backstage
**Client ID:** backstage
**Root URL:** https://backstage.landryzetam.net
**Valid Redirect URI:** https://backstage.landryzetam.net/api/auth/oidc/handler/frame
**Valid Post Logout URI:** https://backstage.landryzetam.net
**Web Origins:** https://backstage.landryzetam.net

## Important Notes

### OIDC Won't Work with Vanilla Image

The official Backstage image (`ghcr.io/backstage/backstage:latest`) **does NOT include the OIDC auth backend module**.

**Current behavior:** Backstage will deploy but OIDC login won't work - users will hit an error.

**To fix:** Need to build custom Backstage backend with `@backstage/plugin-auth-backend-module-oidc-provider` installed and loaded in `packages/backend/src/index.ts`.

See `NEXT-STEPS.md` for detailed custom backend build instructions.

### Alternatives

1. **Use guest access temporarily** - Remove `signInPage: oidc` to allow guest login
2. **Build custom backend** - Add OIDC module and create custom Docker image
3. **Wait for RHDH fix** - Monitor RHDH releases for plugin catalog fixes

## Git History

```
5b35a2b8 - fix(backstage): revert to vanilla Backstage with official trusted image
f1952e3c - fix(backstage): disable RHDH catalog index image
[earlier commits with RHDH attempts]
```

## Related Documentation

- `KEYCLOAK-SETUP.md` - Keycloak OIDC client setup guide
- `NEXT-STEPS.md` - Deployment steps and custom backend guide
- `../../staging/kustomization.yaml` - Where to re-enable deployment
