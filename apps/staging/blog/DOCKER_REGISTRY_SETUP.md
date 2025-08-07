# Docker Registry Secret Setup for Blog

This directory contains the necessary files to configure Docker Hub credentials for pulling the private `lzetam/hugo:latest` image.

## Setup Instructions

1. **Generate the base64 encoded Docker config JSON:**
   ```bash
   chmod +x generate-docker-config-json.sh
   ./generate-docker-config-json.sh lzetam YOUR_DOCKERHUB_PERSONAL_ACCESS_TOKEN
   ```

2. **Edit the unencrypted secret file:**
   - Open `docker-registry-secret-unencrypted-fixed.yaml`
   - Replace `BASE64_ENCODED_DOCKER_CONFIG_JSON` with the output from step 1

3. **Encrypt the secret with SOPS:**
   ```bash
   sops -e docker-registry-secret-unencrypted-fixed.yaml > docker-registry-secret.yaml
   ```

4. **Delete the unencrypted files:**
   ```bash
   rm docker-registry-secret-unencrypted*.yaml
   rm docker-registry-secret-correct.yaml
   ```

5. **Commit and push the changes:**
   ```bash
   git add docker-registry-secret.yaml
   git commit -m "Update Docker Hub credentials for blog namespace"
   git push
   ```

## Files

- `docker-registry-secret.yaml` - The SOPS-encrypted secret (safe to commit)
- `docker-registry-secret-unencrypted-fixed.yaml` - Template for credentials (DO NOT COMMIT)
- `generate-docker-config-json.sh` - Helper script to generate base64 encoded Docker config
- This README file

## Important Notes

- The secret must use the `data` field with base64 encoded content (not `stringData`)
- The Docker config JSON must be base64 encoded before SOPS encryption
- Use the `generate-docker-config-json.sh` script to ensure proper formatting

## Security Notes

- Never commit the unencrypted secret files
- Always use a Docker Hub personal access token, not your password
- The `.gitignore` file has been updated to exclude `*-unencrypted*.yaml` files

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

## Troubleshooting

If you get JSON formatting errors:
- Ensure you're using the `data` field, not `stringData`
- Make sure the Docker config JSON is properly base64 encoded
- Use the provided scripts to generate the correct format
