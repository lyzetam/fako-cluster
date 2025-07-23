# Security Logs Storage Configuration

## Overview
This document describes the setup for dedicated security logs storage and the resolution of kubescape deployment issues.

## Changes Made

### 1. Storage Class for Security Logs
- Added `nfs-security-logs` storage class configuration to `/infrastructure/controllers/base/nfs-storage/dynamic-storageclass-job.yaml`
- The storage class will be created automatically when the NFS storage job runs
- Currently using `nfs-csi-v2` as a temporary storage class until `nfs-security-logs` is available

### 2. Kubescape Configuration
- Converted from continuous deployment to CronJob-based scanning (runs every 6 hours)
- Created separate web deployment for serving scan results
- Updated storage configuration to use ReadWriteMany access mode for shared access
- Files modified:
  - `apps/base/kubescape/cronjob.yaml` - New CronJob for periodic scanning
  - `apps/base/kubescape/web-deployment.yaml` - Nginx deployment for web UI
  - `apps/base/kubescape/storage.yaml` - Updated to use RWX and nfs-csi-v2 (temporarily)
  - `apps/base/kubescape/kustomization.yaml` - Updated to use new components

### 3. Kube-bench Configuration
- Updated storage configuration to use ReadWriteMany access mode
- Updated to use nfs-csi-v2 storage class (temporarily)
- File modified:
  - `apps/base/kube-bench/storage.yaml` - Updated to use RWX and nfs-csi-v2

## Next Steps

1. **Update Storage Class References**: Once the `nfs-security-logs` storage class is created, update both security tools:
   ```bash
   # Update kubescape storage
   kubectl patch pvc kubescape-results -n kubescape -p '{"spec":{"storageClassName":"nfs-security-logs"}}'
   
   # Update kube-bench storage
   kubectl patch pvc kube-bench-results -n kube-bench -p '{"spec":{"storageClassName":"nfs-security-logs"}}'
   ```

2. **Trigger Manual Scans** (optional):
   ```bash
   # Kubescape manual scan
   kubectl create job --from=cronjob/kubescape-scanner kubescape-manual-scan -n kubescape
   
   # Kube-bench manual scan
   kubectl create job --from=cronjob/kube-bench-scanner kube-bench-manual-scan -n kube-bench
   ```

3. **Access Web UI**: The kubescape web UI is available at the configured ingress URL (kubescape.landryzetam.net)

## Architecture

```
┌─────────────────────────┐
│   Security Scanners     │
├─────────────────────────┤
│  - Kubescape CronJob    │
│  - Kube-bench CronJob   │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│  NFS Security Logs      │
│  Storage Class          │
├─────────────────────────┤
│  - Shared storage       │
│  - Persistent results   │
│  - Web accessible       │
└─────────────────────────┘
           │
           ▼
┌─────────────────────────┐
│   Web UI (Nginx)        │
├─────────────────────────┤
│  - Serves scan results  │
│  - JSON viewer          │
│  - Directory listing    │
└─────────────────────────┘
```

## Troubleshooting

- If pods are pending, check PVC status: `kubectl get pvc -n <namespace>`
- If storage class is missing: `kubectl get storageclass`
- Check job logs: `kubectl logs -n <namespace> -l job-name=<job-name>`
