# Housekeeping CronJob

This CronJob performs cluster-wide cleanup of completed and failed pods to prevent accumulation of finished pods in the cluster.

## Overview

The housekeeping job runs every hour and:
- Scans all namespaces for pods in `Succeeded` or `Failed` states
- Deletes these pods to free up resources
- Provides detailed logging of all cleanup operations
- Cleans up its own job pods after 1 hour

## Configuration

### Schedule
- Default: `0 * * * *` (every hour on the hour)
- Modify in `cronjob.yaml` if different frequency is needed

### Self-Cleanup
- Job pods are automatically cleaned up after 1 hour (`ttlSecondsAfterFinished: 3600`)
- This prevents the cleanup job itself from creating clutter

### Permissions
The job has minimal permissions:
- List and get pods across all namespaces
- Delete pods
- List namespaces

## Manual Execution

To run the cleanup manually:

```bash
kubectl create job --from=cronjob/housekeeping housekeeping-manual -n housekeeping
```

## Monitoring

View recent job executions:
```bash
kubectl get jobs -n housekeeping
```

View logs from the most recent run:
```bash
kubectl logs -n housekeeping -l app=housekeeping --tail=100
```

## Customization

### Exclude Specific Namespaces
To exclude certain namespaces from cleanup, modify the script in `configmap.yaml`:

```bash
# Skip certain namespaces
if [[ "$ns" == "kube-system" || "$ns" == "critical-app" ]]; then
    continue
fi
```

### Adjust Pod Age Threshold
To only delete pods older than a certain age, add age checking to the script:

```bash
# Only delete pods older than 24 hours
pod_age_seconds=$(( $(date +%s) - $(date -d "$age" +%s) ))
if [ $pod_age_seconds -gt 86400 ]; then
    kubectl delete pod "$pod" -n "$namespace"
fi
```

## Troubleshooting

If the job is not cleaning up pods:
1. Check job logs for errors
2. Verify RBAC permissions are correct
3. Ensure the service account has cluster-wide access
4. Check if pods have finalizers preventing deletion

## Notes

- The job uses `--grace-period=0 --force` to ensure pod deletion
- Colors in output help distinguish different operations
- Statistics are provided at the end of each run
