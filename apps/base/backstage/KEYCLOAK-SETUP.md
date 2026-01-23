# Keycloak OIDC Setup for Backstage

## Step 1: Access Keycloak Admin Console

1. Open https://auth.landryzetam.net in your browser
2. Click "Administration Console"
3. Log in with admin credentials

## Step 2: Create Backstage OIDC Client

1. Select the appropriate realm (or create a new one, e.g., "backstage")
2. Navigate to **Clients** in the left sidebar
3. Click **Create client**

### Client Configuration:

**General Settings:**
- Client type: `OpenID Connect`
- Client ID: `backstage`
- Name: `Backstage Developer Portal`
- Description: `Authentication for Backstage`

**Capability config:**
- Client authentication: `ON` (required for confidential client)
- Authorization: `OFF`
- Authentication flow:
  - ✅ Standard flow (Authorization Code Flow)
  - ✅ Direct access grants
  - ❌ Implicit flow (deprecated)

**Login settings:**
- Valid redirect URIs: `https://backstage.landryzetam.net/api/auth/oidc/handler/frame`
- Valid post logout redirect URIs: `https://backstage.landryzetam.net`
- Web origins: `https://backstage.landryzetam.net`

4. Click **Save**

## Step 3: Get Client Secret

1. Go to the **Credentials** tab of your new client
2. Copy the **Client Secret** value

## Step 4: Get Metadata URL

The metadata URL format is:
```
https://auth.landryzetam.net/realms/{realm-name}/.well-known/openid-configuration
```

For example, if using the "master" realm:
```
https://auth.landryzetam.net/realms/master/.well-known/openid-configuration
```

Or if you created a "backstage" realm:
```
https://auth.landryzetam.net/realms/backstage/.well-known/openid-configuration
```

## Step 5: Generate Backend Secret

Generate a random secret for Backstage backend authentication:

```bash
openssl rand -base64 32
```

## Step 6: Store Credentials in AWS Secrets Manager

Run the following command to create the secret:

```bash
aws secretsmanager create-secret \
  --name "/fako/backstage/keycloak-oidc" \
  --secret-string '{
    "client_id": "backstage",
    "client_secret": "YOUR_KEYCLOAK_CLIENT_SECRET_HERE",
    "metadata_url": "https://auth.landryzetam.net/realms/master/.well-known/openid-configuration",
    "backend_secret": "YOUR_GENERATED_BACKEND_SECRET_HERE"
  }'
```

Replace:
- `YOUR_KEYCLOAK_CLIENT_SECRET_HERE` with the secret from Step 3
- `YOUR_GENERATED_BACKEND_SECRET_HERE` with the secret from Step 5
- Update the `metadata_url` realm name if not using "master"

If the secret already exists, use update instead:

```bash
aws secretsmanager put-secret-value \
  --secret-id "/fako/backstage/keycloak-oidc" \
  --secret-string '{
    "client_id": "backstage",
    "client_secret": "YOUR_KEYCLOAK_CLIENT_SECRET_HERE",
    "metadata_url": "https://auth.landryzetam.net/realms/master/.well-known/openid-configuration",
    "backend_secret": "YOUR_GENERATED_BACKEND_SECRET_HERE"
  }'
```

## Step 7: Deploy Changes

```bash
cd /Users/zz/second-brain/dev/fako-cluster
git add apps/base/backstage/
git commit -m "feat(backstage): switch to RHDH with Keycloak OIDC authentication"
git push origin main

# Wait for Flux to reconcile
flux reconcile source git flux-system
flux reconcile kustomization apps

# Check deployment status
kubectl rollout status deployment/backstage -n backstage
kubectl get pods -n backstage
```

## Step 8: Verify Authentication

1. Open https://backstage.landryzetam.net
2. You should be redirected to Keycloak login
3. Log in with a Keycloak user
4. You should be redirected back to Backstage and authenticated

## Step 9: Configure User/Group Sync (Optional)

To import users and groups from Keycloak into Backstage catalog, enable the Keycloak catalog provider:

Add to `apps/base/backstage/configmap-app-config.yaml`:

```yaml
catalog:
  providers:
    keycloakOrg:
      default:
        baseUrl: https://auth.landryzetam.net
        loginRealm: master
        realm: master
        clientId: ${AUTH_OIDC_CLIENT_ID}
        clientSecret: ${AUTH_OIDC_CLIENT_SECRET}
        schedule:
          frequency: { minutes: 30 }
          timeout: { minutes: 3 }
```

## Troubleshooting

### Authentication fails with "invalid_client"
- Verify client_id matches exactly in Keycloak and AWS Secrets Manager
- Verify client_secret is correct
- Check that client authentication is enabled in Keycloak

### Redirect URI mismatch
- Verify the redirect URI in Keycloak matches: `https://backstage.landryzetam.net/api/auth/oidc/handler/frame`
- Check for trailing slashes or protocol mismatches

### Metadata URL unreachable
- Verify the realm name in the metadata URL
- Check that Keycloak is accessible from the cluster
- Note: Keycloak 17+ removed the `/auth` path prefix

### Pod logs show auth errors
```bash
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100
```
