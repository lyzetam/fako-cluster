# How to View Kubescape Security Reports in Headlamp

## Current Setup
- **Kubescape Operator**: v1.28.4 (running without cloud component)
- **Available CRDs**: Limited (operatorcommands, runtimerulealertbindings)
- **Scan Schedule**: Automated scans run daily

## Viewing Security Data in Headlamp

### 1. Check Scan Jobs
In Headlamp, navigate to:
- **Workloads** → **Jobs**
- Select namespace: `kubescape`
- Look for jobs like `manual-scan-*` or scheduled scan jobs

To view scan results:
1. Click on a completed job
2. Go to the **Pods** tab
3. Click on the pod
4. Click **Logs** to see the scan output

### 2. View Custom Resources
Navigate to:
- **Custom Resources**
- Look for:
  - `operatorcommands.kubescape.io`
  - `runtimerulealertbindings.kubescape.io`

### 3. Check CronJobs
Navigate to:
- **Workloads** → **CronJobs**
- Select namespace: `kubescape`
- You'll see:
  - `kubescape-scheduler` - Runs compliance scans
  - `kubevuln-scheduler` - Runs vulnerability scans

### 4. View Operator Logs
For real-time monitoring:
1. Go to **Workloads** → **Deployments**
2. Select namespace: `kubescape`
3. Click on `operator`
4. Go to **Pods** tab
5. Click on the pod and view **Logs**

## Manual Scan Triggering

To trigger a manual scan (run in terminal):
```bash
# Compliance scan
kubectl create job --from=cronjob/kubescape-scheduler manual-scan-$(date +%s) -n kubescape

# Wait for completion
kubectl wait --for=condition=complete job/manual-scan-<timestamp> -n kubescape --timeout=5m

# View results
kubectl logs job/manual-scan-<timestamp> -n kubescape
```

## Understanding Scan Results

When viewing job logs, you'll see:
- **Framework compliance scores** (NSA, MITRE, CIS)
- **Failed controls** with severity levels
- **Affected resources**
- **Remediation suggestions**

## Limitations

Due to the operator being configured without cloud storage:
- No persistent vulnerability database
- No historical trend data
- Limited CRD availability
- Results are only available in job logs

## Next Steps

For a fuller experience, consider:
1. Enabling the cloud component in Kubescape operator
2. Setting up a dedicated logging solution (e.g., Loki) to persist scan results
3. Creating custom dashboards using the metrics exposed by the operator
