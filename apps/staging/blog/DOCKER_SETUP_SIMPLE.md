# Simple Docker Hub Setup for Blog

## Quick Setup

1. **Edit the secret file** (`dockerhub-secret.yaml`):
   - Replace `YOUR_DOCKERHUB_PERSONAL_ACCESS_TOKEN` with your Docker Hub token

2. **Encrypt it with SOPS**:
   ```bash
   sops -e dockerhub-secret.yaml > dockerhub-secret.yaml.tmp
   mv dockerhub-secret.yaml.tmp dockerhub-secret.yaml
   ```

3. **Commit and push**:
   ```bash
   git add -A
   git commit -m "Update Docker Hub credentials"
   git push
   ```

That's it! The system will automatically:
- Deploy your encrypted credentials
- Run a job to create the proper Docker registry secret
- The Hugo pod will use it to pull the private image

## How it Works

1. You provide simple username/password in a standard Kubernetes secret
2. A Job automatically converts it to the Docker registry format
3. The deployment uses the generated registry secret

## Files

- `dockerhub-secret.yaml` - Simple secret with username/password (SOPS encrypted)
- `create-docker-registry-secret-job.yaml` - Job that creates the registry secret
- The deployment references `dockerhub-registry` secret for pulling images
