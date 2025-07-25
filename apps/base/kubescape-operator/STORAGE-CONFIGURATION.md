# Kubescape Storage Configuration

## Overview

This document describes the storage configuration for Kubescape Operator to address ephemeral storage limitations.

## Storage Components

### 1. Persistent Storage for Vulnerability Database

- **Purpose**: Store vulnerability database cache persistently to avoid re-downloading on pod restarts
- **Storage Class**: `nfs-security-logs`
- **Size**: 10Gi
- **Mount Path**: `/home/nonroot/.cache`
- **Component**: kubevuln

### 2. Persistent Storage for Scan Results

- **Purpose**: Store security scan results and reports
- **Storage Class**: `nfs-security-logs`
- **Size**: 20Gi
- **Component**: All Kubescape components

### 3. Ephemeral Storage Limits

To prevent pods from being evicted due to ephemeral storage usage:

| Component | Request | Limit |
|-----------|---------|-------|
| operator  | 1Gi     | 2Gi   |
| kubevuln  | 2Gi     | 5Gi   |
| gateway   | 1Gi     | 2Gi   |

## Monitoring

To monitor storage usage:

```bash
# Check PVC usage
kubectl get pvc -n kubescape

# Check pod ephemeral storage usage
kubectl top pods -n kubescape --containers

# Check vulnerability database cache size
kubectl exec -n kubescape deployment/kubevuln -- du -sh /home/nonroot/.cache
```

## Troubleshooting

If you encounter storage issues:

1. **Check PVC status**:
   ```bash
   kubectl describe pvc -n kubescape
   ```

2. **Monitor ephemeral storage**:
   ```bash
   kubectl describe pod -n kubescape | grep -A 5 "ephemeral-storage"
   ```

3. **Clear old vulnerability data if needed**:
   ```bash
   kubectl exec -n kubescape deployment/kubevuln -- rm -rf /home/nonroot/.cache/old-data
   ```

## Storage Class Details

The `nfs-security-logs` storage class is configured in the infrastructure layer with:
- NFS server backend
- Retain reclaim policy
- Volume expansion enabled
- Optimized mount options for security logs
