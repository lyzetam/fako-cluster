# Cloudflare Tunnel Setup for GPUStack Proxy

## Current Configuration

The Cloudflare tunnel has been configured for gpustack-proxy with the following settings:

- **URL**: https://gpustack.landryzetam.net
- **Tunnel Name**: audiobooks (reusing existing tunnel)
- **Service Target**: http://gpustack:80
- **Replicas**: 2 (for high availability)

## Files Created

1. `cloudflare.yaml` - Contains the cloudflared deployment and ConfigMap
2. `cloudflare-secret.yaml` - Contains the encrypted tunnel credentials (currently commented out in kustomization)

## What You Need to Do

1. **In Cloudflare Dashboard**:
   - Add the route `gpustack.landryzetam.net` to the `audiobooks` tunnel
   - Ensure the DNS record for `gpustack.landryzetam.net` is configured

2. **Add Tunnel Credentials**:
   You need to create the tunnel-credentials secret in the gpustack-proxy namespace. You can either:
   
   a) Copy from another namespace if you have the audiobooks tunnel credentials:
   ```bash
   kubectl get secret tunnel-credentials -n <source-namespace> -o yaml | \
   sed 's/namespace: .*/namespace: gpustack-proxy/' | \
   kubectl apply -f -
   ```
   
   b) Create a new secret with the tunnel credentials JSON file:
   ```bash
   kubectl create secret generic tunnel-credentials \
     --from-file=credentials.json=<path-to-credentials-file> \
     -n gpustack-proxy
   ```

3. **Deploy the Cloudflare Tunnel**:
   Once the credentials are in place, apply the configuration:
   ```bash
   kubectl apply -k apps/staging/gpustack-proxy/
   ```

## Verification

After deployment, verify the tunnel is working:
```bash
# Check pods are running
kubectl get pods -n gpustack-proxy

# Check logs
kubectl logs -n gpustack-proxy -l app=cloudflared

# Test the URL
curl -I https://gpustack.landryzetam.net
