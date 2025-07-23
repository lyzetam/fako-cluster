# Kube-bench Security Scanner

This directory contains the Kubernetes manifests for deploying kube-bench, a security scanner that checks whether Kubernetes is deployed securely by running checks documented in the CIS Kubernetes Benchmark.

## Overview

Kube-bench is deployed as a CronJob that runs daily at 2 AM to perform security scans of the Kubernetes cluster and output results in JSON format.

## Components

- **Namespace**: `kube-bench` (dedicated namespace for kube-bench)
- **ServiceAccount**: `kube-bench` with appropriate RBAC permissions
- **ClusterRole**: Permissions to read cluster resources for security scanning
- **PersistentVolumeClaim**: 5Gi storage for historical scan results
- **CronJob**: Scheduled daily execution of kube-bench scanner

## Features

- **Automated Scanning**: Runs daily at 2 AM UTC
- **CIS Compliance**: Checks against CIS Kubernetes Benchmark
- **JSON Output**: Results are output in JSON format for easy parsing
- **Persistent Storage**: Results stored in PVC with timestamps for historical tracking
- **Host Access**: Uses privileged security context to access host filesystem
- **Results Processing**: Includes a sidecar container to display scan results

## Security Considerations

- The kube-bench pod runs with `privileged: true` and `hostPID: true` to access host resources
- Mounts various host paths to scan Kubernetes components
- Has broad cluster-level read permissions through ClusterRole

## Monitoring

- Job history is limited to 3 successful and 3 failed jobs
- Concurrency policy prevents overlapping scans
- Results are logged to container output for collection by logging systems

## Manual Execution

To run kube-bench manually:

```bash
kubectl create job --from=cronjob/kube-bench-scanner manual-kube-bench-scan -n kube-bench
```

## Results

Scan results are available in:
- Container logs via `kubectl logs`
- Persistent storage at `/results/kube-bench-results-YYYYMMDD-HHMMSS.json` in the PVC
- Historical results can be accessed by mounting the PVC to inspect past scans

To access stored results:
```bash
# List all stored results
kubectl exec -n kube-bench deployment/kube-bench-results-viewer -- ls -la /results/

# View a specific result file
kubectl exec -n kube-bench deployment/kube-bench-results-viewer -- cat /results/kube-bench-results-YYYYMMDD-HHMMSS.json
```

## Configuration

The CronJob can be customized by modifying:
- Schedule in `cronjob.yaml`
- Resource limits and requests
- Additional kube-bench command arguments
