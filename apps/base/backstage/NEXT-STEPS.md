# Backstage Next Steps

## Current State

**Reverted to vanilla Backstage** with official trusted image: `ghcr.io/backstage/backstage:latest`

- RHDH was causing init container crashes due to dynamic plugins issues
- Using official Backstage image for safety and simplicity
- Deployment should now start successfully

## OIDC Authentication Status

⚠️ **OIDC configuration is present in release.yaml but WILL NOT WORK with vanilla image**

The official Backstage image does NOT include the OIDC auth backend module. OIDC authentication requires a custom backend build.

### Why Custom Backend is Needed

Vanilla Backstage image requires adding `@backstage/plugin-auth-backend-module-oidc-provider` and loading it in `packages/backend/src/index.ts`:

```typescript
backend.add(import('@backstage/plugin-auth-backend-module-oidc-provider'));
```

This cannot be done at runtime - it requires building a custom Docker image.

## What's Working Now

- ✅ Backstage will deploy with vanilla image
- ✅ Guest authentication enabled (default)
- ✅ Keycloak client created and configured
- ✅ ExternalSecret configured for OIDC credentials
- ❌ OIDC authentication (requires custom backend)

## Required Actions

### 1. Create AWS Secret (REQUIRED)

The ExternalSecret is looking for `/fako/backstage/keycloak-oidc` but it doesn't exist yet:

```bash
# Generate a secure backend secret
BACKEND_SECRET=$(openssl rand -base64 32)

# Create the secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "/fako/backstage/keycloak-oidc" \
  --secret-string "{
    \"client_id\": \"backstage\",
    \"client_secret\": \"<GET_FROM_KEYCLOAK_CLIENT>\",
    \"metadata_url\": \"https://auth.landryzetam.net/realms/master/.well-known/openid-configuration\",
    \"backend_secret\": \"${BACKEND_SECRET}\"
  }"
```

To get the client secret from Keycloak:
1. Go to https://auth.landryzetam.net
2. Login with: admin / Admin#toKbiz-cysze4-wornem!
3. Navigate to Clients → backstage → Credentials tab
4. Copy the Client Secret

### 2. To Enable OIDC (OPTIONAL - Future Work)

Build custom Backstage backend with OIDC module:

```bash
# In a new backstage-custom directory:
npx @backstage/create-app@latest

# Add OIDC module
cd backstage-custom
yarn add --cwd packages/backend @backstage/plugin-auth-backend-module-oidc-provider

# Edit packages/backend/src/index.ts
# Add: backend.add(import('@backstage/plugin-auth-backend-module-oidc-provider'));

# Build and push Docker image
docker build -t lzetam/backstage-custom:latest .
docker push lzetam/backstage-custom:latest

# Update release.yaml to use custom image
```

## Deployment

Once AWS secret is created:

```bash
git add .
git commit -m "fix(backstage): revert to vanilla image with trusted sources"
git push
flux reconcile source git flux-system
flux reconcile kustomization apps
```

## Security Note

✅ Using official trusted images only:
- `ghcr.io/backstage/backstage:latest` (official Backstage image)
- No third-party or unverified container images

RHDH images (`quay.io/rhdh-community/rhdh`) were removed due to plugin installation issues.
