# Kubevuln Readiness Probe Fix

## Issue
The kubevuln pod fails readiness probes with timeout errors. The default probe timeout in the Helm chart is only 1 second, which is insufficient during startup when the grype vulnerability database is being updated.

## Root Cause
- Default readiness probe timeout: 1s (too short)
- Grype database update on startup takes 1-2 minutes
- The Kubescape Helm chart doesn't expose probe configuration values

## Temporary Solution
A manual patch must be applied to the kubevuln deployment after it's created by the HelmRelease:

```bash
kubectl patch deployment kubevuln -n kubescape --type=strategic --patch='
spec:
  template:
    spec:
      containers:
      - name: kubevuln
        readinessProbe:
          httpGet:
            path: /v1/readiness
            port: 8080
          initialDelaySeconds: 60
          timeoutSeconds: 10
          periodSeconds: 10
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /v1/liveness
            port: 8080
          initialDelaySeconds: 90
          timeoutSeconds: 10
          periodSeconds: 30
          failureThreshold: 3
'
```

## Probe Configuration Details
- **Readiness Probe**:
  - Initial delay: 60s (allows time for grype DB update)
  - Timeout: 10s (increased from 1s)
  - Period: 10s
  - Failure threshold: 3

- **Liveness Probe**:
  - Initial delay: 90s (starts after readiness probe)
  - Timeout: 10s
  - Period: 30s
  - Failure threshold: 3

## Long-term Solution
Work with the Kubescape team to expose probe configuration options in their Helm chart values. This would allow us to configure the probes through GitOps via the HelmRelease values.

## Monitoring
To check if the fix is applied:
```bash
kubectl get deployment -n kubescape kubevuln -o yaml | grep -A 5 "timeoutSeconds:"
```

If the timeout shows as 1s, the patch needs to be reapplied.

## Note
This patch will be overwritten whenever the HelmRelease is upgraded. The patch must be reapplied after any Helm upgrades until a permanent solution is implemented.
