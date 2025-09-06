# Pixie Observability Platform (Helm Deployment)

This deployment sets up Pixie (Vizier) connected to Cosmic Cloud for eBPF-based observability using Helm.

## Overview

Pixie uses eBPF to automatically capture telemetry data without manual instrumentation. This deployment:
- Uses Helm to manage the Pixie operator and Vizier components
- Deploys to the `pl` namespace  
- Connects to Cosmic Cloud (getcosmic.ai) for the cloud backend
- Requires privileged pods for eBPF functionality

## Prerequisites

1. **Kubernetes cluster requirements**:
   - Linux nodes with kernel 4.14+ (eBPF support)
   - Privileged pods allowed
   - Outbound HTTPS (443) to getcosmic.ai

2. **Cosmic Cloud account and Deploy Key**:
   - Sign up at https://getcosmic.ai
   - Get a deploy key (see instructions below)

3. **OLM (Operator Lifecycle Manager)**:
   - Should already be installed (check with: `kubectl get ns olm`)
   - If not present, the Helm chart can install it

## Getting a Deploy Key

### Option 1: Using the Pixie CLI
```bash
# Install the Pixie CLI
bash -c "$(curl -fsSL https://getcosmic.ai/install.sh)"

# Set the cloud endpoint
export PX_CLOUD_ADDR=getcosmic.ai

# Authenticate (will open browser)
px auth login

# Create a deploy key
px deploy-key create

# List deploy keys
px deploy-key list
```

### Option 2: Via Cosmic Cloud UI
1. Log into your Cosmic Cloud account
2. Navigate to Admin/Settings
3. Look for "Deploy Keys" or "API Keys" section
4. Create a new deploy key for your cluster

## Configuration Steps

### 1. Store Deploy Key in AWS Secrets Manager

Once you have your deploy key, store it in AWS Secrets Manager:

```bash
# Store in AWS Secrets Manager
aws secretsmanager create-secret \
  --name /observability/pixie/deploy_key \
  --secret-string '{"key":"YOUR_DEPLOY_KEY_HERE"}' \
  --region us-east-1
```

### 2. Enable the ExternalSecret

Uncomment the ExternalSecret in `kustomization.yaml`:

```yaml
resources:
  - namespace.yaml
  - helm-repository.yaml
  - helm-release.yaml
  - external-secret-deploy-key.yaml  # <-- Uncomment this line
```

Also uncomment the contents of `external-secret-deploy-key.yaml`.

### 3. Enable valuesFrom in HelmRelease

In `helm-release.yaml`, uncomment the valuesFrom section:

```yaml
  valuesFrom:
  - kind: Secret
    name: pixie-deploy-key
    valuesKey: deploy-key
    targetPath: deployKey
```

### 4. Update Cluster Name

In `helm-release.yaml`, update the cluster name:

```yaml
values:
  clusterName: "your-actual-cluster-name"  # Change this
```

## Deployment

The deployment is managed through Flux GitOps:

```bash
# Commit and push your changes
git add .
git commit -m "feat: configure Pixie deployment with deploy key"
git push

# Trigger Flux reconciliation
flux reconcile kustomization apps -n flux-system

# Monitor deployment
kubectl get pods -n pl -w
```

## Verification

### 1. Check Helm release status
```bash
helm list -n pl
flux get helmrelease -n pl
```

### 2. Check pod deployment
```bash
# Check all Pixie components
kubectl get pods -n pl

# Expected pods:
# - kelvin-*
# - pl-nats-*
# - vizier-certmgr-*
# - vizier-cloud-connector-*
# - vizier-metadata-*
# - vizier-pem-* (one per node)
# - vizier-proxy-*
# - vizier-query-broker-*

# Also check operator namespace
kubectl get pods -n px-operator
```

### 3. Verify cloud connection
```bash
# Check cloud connector logs
kubectl logs -n pl -l app=pl-cloud-connector --tail=50

# Should see successful authentication/connection to getcosmic.ai
```

### 4. Using Pixie CLI
```bash
# Set cloud endpoint
export PX_CLOUD_ADDR=getcosmic.ai

# List connected clusters
px get viziers

# Check cluster status
px status

# Run sample queries
px scripts list
px live px/http_data
px live px/cluster
```

### 5. Access Web UI
- Log into your Cosmic Cloud account
- Navigate to the Live UI
- Select your cluster from the dropdown
- Run scripts like `px/cluster` or `px/http_data`

## Resource Configuration

Current settings in `helm-release.yaml`:
- PEM memory limit: 1Gi (minimum recommended)
- Component memory limits: 512Mi each
- Auto-update: enabled by default

## Troubleshooting

### Deploy Key Issues
```bash
# Check if secret was created
kubectl get secret pixie-deploy-key -n pl

# Check ExternalSecret status
kubectl describe externalsecret pixie-deploy-key -n pl

# Verify secret content
kubectl get secret pixie-deploy-key -n pl -o jsonpath='{.data.deploy-key}' | base64 -d
```

### Pods not starting
```bash
# Check HelmRelease status
flux get helmrelease pixie -n pl
kubectl describe helmrelease pixie -n pl

# Check events
kubectl get events -n pl --sort-by='.lastTimestamp'

# Check PEM logs (eBPF issues)
kubectl logs -n pl -l app=pl-pem --tail=100
```

### No data in UI
```bash
# Ensure PEM pods on all nodes
kubectl get pods -n pl -l app=pl-pem -o wide

# Check for kernel compatibility
kubectl logs -n pl -l app=pl-pem | grep -i "kernel\|btf\|error"
```

### Connection issues
```bash
# Verify deploy key is correct
kubectl get secret pixie-deploy-key -n pl -o yaml

# Check cloud connector logs
kubectl logs -n pl -l app=pl-cloud-connector -f
```

## Maintenance

### Upgrades
- Flux will handle Helm chart upgrades automatically
- To pin version, update `version: "*"` in `helm-release.yaml`

### Scaling
- PEM agents scale automatically (one per node)
- Other components can be scaled via Helm values

### Monitoring
- Monitor pod resources, especially PEM memory usage
- Set up alerts for pod restarts or failures

## Uninstall

To remove Pixie:
1. Delete from Flux: Remove from `apps/staging/kustomization.yaml`
2. Or manually:
   ```bash
   flux delete helmrelease pixie -n pl
   kubectl delete namespace pl px-operator
   ```

## References
- [Pixie Documentation](https://docs.px.dev/)
- [Cosmic Cloud](https://getcosmic.ai)
- [Pixie Helm Chart](https://artifacthub.io/packages/helm/pixie/pixie-operator-chart)
- [eBPF Introduction](https://ebpf.io/)
