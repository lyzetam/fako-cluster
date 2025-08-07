# Docker Registry Secret Setup for Blog

This directory contains the necessary files to configure Docker Hub credentials for pulling the private `lzetam/hugo:latest` image.

## Setup Instructions

1. **Generate the base64 encoded auth string:**
   ```bash
   chmod +x generate-docker-auth.sh
   ./generate-docker-auth.sh lzetam YOUR_DOCKERHUB_PERSONAL_ACCESS_TOKEN
   ```

2. **Edit the unencrypted secret file:**
   - Open `docker-registry-secret-unencrypted.yaml`
   - Replace the placeholders:
     - `YOUR_DOCKERHUB_PERSONAL_ACCESS_TOKEN`: Your Docker Hub personal access token
     - `BASE64_ENCODED_lzetam:TOKEN`: The output from step 1

3. **Encrypt the secret with SOPS:**
   ```bash
   sops -e docker-registry-secret-unencrypted.yaml > docker-registry-secret.yaml
   ```

4. **Delete the unencrypted file:**
   ```bash
   rm docker-registry-secret-unencrypted.yaml
   ```

5. **Commit and push the changes:**
   ```bash
   git add docker-registry-secret.yaml
   git commit -m "Update Docker Hub credentials for blog namespace"
   git push
   ```

## Files

- `docker-registry-secret.yaml` - The SOPS-encrypted secret (safe to commit)
- `docker-registry-secret-unencrypted.yaml` - Template for credentials (DO NOT COMMIT)
- `generate-docker-auth.sh` - Helper script to generate base64 auth string
- This README file

## Security Notes

- Never commit the unencrypted secret file
- Always use a Docker Hub personal access token, not your password
- The `.gitignore` file has been updated to exclude `*-unencrypted.yaml` files

## Verification

After applying the secret, you can verify it's working:

```bash
kubectl get secret dockerhub-credentials -n blog
kubectl get pods -n blog -w
```

The pod should successfully pull the image and start running.

## Docker Hub Personal Access Token

To create a personal access token:
1. Log in to Docker Hub
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a descriptive name (e.g., "fako-cluster-blog")
5. Select "Read" permissions (for pulling images)
6. Copy the token and use it in the secret configuration
