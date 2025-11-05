# Audio Compressor Deployment

Nightly batch processing service that downloads audio files from the SFTP server, compresses them using FFmpeg, and stores them in a persistent volume accessible via SFTP.

## Architecture

### Namespace Layout
```
audio-compressor namespace:
  - CronJob that runs nightly at 2 AM
  - Pulls private image from lzetam/audio-compressor:latest
  - Mounts PVC from sftp-server namespace

sftp-server namespace:
  - audio-compressed-pvc (100Gi, ReadWriteMany, nfs)
  - Mounted by SFTP server at /home/sftpuser/compressed (read-only)
  - Mounted by audio-compressor job (read-write)
```

### Storage Flow
```
SFTP Server (/audio) → Audio Compressor Job → SFTP Server (/compressed)
     ↓                                                    ↑
 Original files                                   Compressed files
 (unifi-journals-pvc)                        (audio-compressed-pvc)
```

### Access Pattern
- **SFTP users** can access:
  - `/audio/` - Original recordings (read-only)
  - `/compressed/` - Compressed files (read-only)
- **Audio compressor job** connects via SFTP to download originals, then saves compressed files directly to PVC

## Deployment

### Prerequisites

1. **AWS Secrets Manager** must contain:
   - `sftp/audio-server` with keys: `username`, `password`
   - `dockerhub/credentials` with keys: `username`, `password`

2. **NFS Storage Class** must be available for ReadWriteMany PVC

3. **SOPS encryption key** configured for the cluster

### Initial Setup

The AWS credentials are already encrypted with SOPS (reused from other namespaces).

**Simply commit and push**:
```bash
git add .
git commit -m "feat: deploy audio-compressor nightly job"
git push
```

5. **Verify deployment**:
   ```bash
   # Check if namespace is created
   kubectl get namespace audio-compressor
   
   # Check if secrets are synced from AWS
   kubectl get externalsecret -n audio-compressor
   kubectl get secret -n audio-compressor
   
   # Check if CronJob is created
   kubectl get cronjob -n audio-compressor
   
   # Check if PVC is created and accessible
   kubectl get pvc -n sftp-server audio-compressed-pvc
   
   # Manually trigger a test run
   kubectl create job --from=cronjob/audio-compressor audio-compressor-test -n audio-compressor
   
   # Watch the job
   kubectl logs -f -n audio-compressor job/audio-compressor-test
   ```

## Configuration

All configuration is via environment variables in the CronJob. Key settings:

| Variable | Value | Description |
|----------|-------|-------------|
| `SFTP_HOST` | `sftp-service.sftp-server.svc.cluster.local` | Internal cluster DNS |
| `SFTP_PORT` | `22` | Standard SSH port |
| `SFTP_REMOTE_PATH` | `/audio` | Source directory on SFTP |
| `OUTPUT_DIR` | `/data/compressed` | Destination on PVC |
| `SCHEDULE` | `0 2 * * *` | Runs at 2 AM daily |
| `SAMPLE_RATE` | `16000` | 16kHz for Whisper compatibility |
| `CHANNELS` | `1` | Mono audio |
| `BITRATE` | `32k` | 32 kbps for speech |

## SFTP Access

After deployment, compressed files are accessible via SFTP:

```bash
# Connect to SFTP
sftp sftpuser@<sftp-service-external-ip>

# List compressed files
sftp> ls compressed/
compressed/10-17-25_compressed.wav
compressed/10-17-25-01_compressed.wav
compressed/manifest.json

# Download a file
sftp> get compressed/10-17-25_compressed.wav
```

## Monitoring

### Check CronJob Status
```bash
kubectl get cronjob -n audio-compressor
kubectl describe cronjob audio-compressor -n audio-compressor
```

### View Job History
```bash
kubectl get jobs -n audio-compressor --sort-by=.status.startTime
```

### View Logs
```bash
# Latest job
kubectl logs -n audio-compressor -l job-name=audio-compressor-<timestamp>

# Follow logs during execution
kubectl logs -f -n audio-compressor -l job-name=audio-compressor-<timestamp>
```

### Check PVC Usage
```bash
kubectl exec -it -n sftp-server deployment/sftp-server -- df -h /home/sftpuser/compressed
kubectl exec -it -n sftp-server deployment/sftp-server -- ls -lh /home/sftpuser/compressed
```

### View Manifest
```bash
kubectl exec -it -n sftp-server deployment/sftp-server -- cat /home/sftpuser/compressed/manifest.json
```

## Troubleshooting

### Job Fails with ImagePullError
```bash
# Check if Docker registry secret exists
kubectl get secret dockerhub-registry -n audio-compressor

# Check if the job to create it ran
kubectl get job create-docker-registry-secret -n audio-compressor

# Manually trigger secret creation
kubectl delete job create-docker-registry-secret -n audio-compressor
kubectl apply -f apps/base/audio-compressor/create-docker-registry-secret-job.yaml
```

### SFTP Connection Failed
```bash
# Check if SFTP credentials are synced
kubectl get secret sftp-credentials -n audio-compressor
kubectl describe externalsecret sftp-credentials-secret -n audio-compressor

# Test SFTP connectivity from within cluster
kubectl run -it --rm test-sftp --image=alpine --restart=Never -- sh
apk add openssh-client
sftp -P 22 sftpuser@sftp-service.sftp-server.svc.cluster.local
```

### PVC Mount Issues
```bash
# Check if PVC is bound
kubectl get pvc -n sftp-server audio-compressed-pvc

# Check PVC events
kubectl describe pvc audio-compressed-pvc -n sftp-server

# Verify RBAC permissions
kubectl get rolebinding -n sftp-server audio-compressor-pvc-access
```

### Check AWS Secrets Manager Access
```bash
# Verify AWS credentials secret exists
kubectl get secret aws-credentials -n audio-compressor

# Check SecretStore status
kubectl describe secretstore aws-secret-store -n audio-compressor

# Check ExternalSecret sync status
kubectl get externalsecret -n audio-compressor
kubectl describe externalsecret dockerhub-credentials-secret -n audio-compressor
kubectl describe externalsecret sftp-credentials-secret -n audio-compressor
```

## Manual Execution

To manually trigger the job outside the schedule:

```bash
kubectl create job --from=cronjob/audio-compressor manual-run-$(date +%s) -n audio-compressor
```

## Cleanup

To remove the deployment:

```bash
# Remove from staging kustomization
# Edit apps/staging/kustomization.yaml and remove audio-compressor line

# Or directly delete
kubectl delete namespace audio-compressor
kubectl delete pvc audio-compressed-pvc -n sftp-server

# Update SFTP server (remove compressed mount)
# Revert changes to apps/base/sftp-server/deployment.yaml
```

## Security Notes

- ✅ AWS credentials encrypted with SOPS
- ✅ SFTP credentials pulled from AWS Secrets Manager
- ✅ DockerHub credentials pulled from AWS Secrets Manager
- ✅ Container runs with ServiceAccount (non-root)
- ✅ Cross-namespace PVC access via RBAC
- ✅ SFTP server has read-only access to compressed files
