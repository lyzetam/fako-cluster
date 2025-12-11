# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Rules

**ALWAYS:**
- Use GitOps workflow - all changes go through Git, never apply directly with `kubectl apply`
- Use declarative manifests (YAML) - no imperative commands for resource creation
- Trigger Flux reconciliation after pushing changes
- Use SOPS or AWS Secrets Manager for sensitive data

**NEVER:**
- Commit credentials, passwords, API keys, or tokens to the repository
- Hardcode IP addresses in manifests (use DNS names or ConfigMaps)
- Use `kubectl apply` or `kubectl create` directly for persistent changes
- Store secrets in plaintext ConfigMaps or environment variables in Git

## Project Overview

Fako Cluster is a GitOps-managed Kubernetes homelab running on K3s with FluxCD. It hosts AI/ML workloads (Ollama, Whisper, Piper), productivity apps, and infrastructure services across heterogeneous hardware including GPU nodes (RTX 5070, RTX 3050) and ARM devices.

## Common Commands

### GitOps Deployment
```bash
# Deploy changes through GitOps (preferred method)
./scripts/gitops-deploy.sh

# Dry-run mode
./scripts/gitops-deploy.sh --dry-run

# Manual workflow
git add . && git commit -m "feat: description" && git push
flux reconcile source git flux-system
flux reconcile kustomization apps
```

### Flux Operations
```bash
# Check all Flux resources
flux get all -A

# Check for errors only
flux get all -A --status-selector ready=false

# Force full reconciliation (respects dependency order)
flux reconcile source git flux-system
flux reconcile kustomization infrastructure-controllers
flux reconcile kustomization infrastructure-configs
flux reconcile kustomization apps
flux reconcile kustomization monitoring-configs

# View Flux logs
flux logs --follow

# Check specific kustomization
flux logs --kind=Kustomization --name=apps
```

### Flux Kustomization Order
Reconciliation follows this dependency chain:
```
flux-system → infrastructure-controllers → infrastructure-configs → apps → monitoring-configs
```

### Cluster Status
```bash
# Node and pod health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl top nodes

# Recent events (useful for debugging)
kubectl get events -A --sort-by='.lastTimestamp' | head -20

# GPU status
kubectl exec -n gpu-operator -it $(kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset -o jsonpath='{.items[0].metadata.name}') -- nvidia-smi
```

### Node Management
```bash
# Cordon and drain node
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets

# Uncordon after maintenance
kubectl uncordon <node-name>
```

## Architecture

### Repository Structure
```
fako-cluster/
├── apps/                    # Application deployments
│   ├── base/               # Base Kustomize configurations
│   └── staging/            # Production overlays
├── clusters/staging/        # Cluster bootstrap and Flux config
├── infrastructure/
│   ├── configs/            # Infrastructure configuration (certs, NFS, secrets)
│   └── controllers/        # Operators (External Secrets, GPU Operator, CloudNative-PG)
├── monitoring/              # Prometheus, Loki, Grafana stack
├── scripts/                # Deployment and maintenance scripts
└── notes/                  # Documentation and troubleshooting guides
```

### GitOps Flow
Changes are deployed via Git commits. FluxCD watches the repository and automatically reconciles:
1. Push changes to GitHub
2. Flux Source Controller detects changes
3. Kustomize/Helm Controllers apply manifests
4. Resources deploy to cluster

### Application Structure Pattern
Each app in `apps/base/<app-name>/` typically contains:
- `namespace.yaml` - Isolated namespace
- `kustomization.yaml` - Kustomize configuration
- `deployment.yaml` or `deployment-gpu.yaml` - Workload definition
- `service.yaml` - Service definition
- `ingress.yaml` - External access
- `storage.yaml` - PVC definitions
- `configmap.yaml` - Configuration

### Key Infrastructure Components
- **External Secrets Operator**: Syncs secrets from AWS Secrets Manager
- **CloudNative-PG**: PostgreSQL operator for HA database clusters
- **NFS CSI Driver**: Dynamic storage provisioning from UGREEN NAS
- **GPU Operator**: NVIDIA GPU support with device plugin
- **Cert-Manager**: Automated TLS certificates via Let's Encrypt

### Secret Management Pattern
**No secrets in Git. Ever.** Each namespace follows:
1. AWS Secrets Manager holds secret values (preferred) or SOPS-encrypted files
2. `SecretStore` configured per namespace with scoped IAM permissions
3. `ExternalSecret` syncs specific secrets to Kubernetes

For new secrets:
```bash
# Store in AWS Secrets Manager
aws secretsmanager create-secret --name "/fako/<namespace>/<secret-name>" --secret-string '{"key":"value"}'
```

ExternalSecret pattern (this goes in Git, not the actual secret values):
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: <namespace>
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-store
    kind: SecretStore
  target:
    name: app-secrets
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: /fako/<namespace>/<secret-name>
        property: password
```

### GPU Assignment
The `yeezyai` node has dual GPUs:
- **RTX 5070 (12GB)**: Large language models (Ollama)
- **RTX 3050**: Speech-to-text (Whisper)

Deployments use node affinity and `nvidia.com/gpu` resource requests.

## Development Patterns

### Adding a New Application
1. Create directory in `apps/base/<app-name>/`
2. Add Kustomize manifests following existing app patterns
3. Reference in `apps/staging/kustomization.yaml`
4. Commit and push - Flux will deploy
5. Verify with `flux reconcile kustomization apps && flux get kustomization apps`

### Commit Message Convention
- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance
- `docs:` - Documentation
- `refactor:` - Code refactoring

### External Access
- **Internal**: Traefik ingress with TLS
- **External**: Cloudflare Tunnels (no port forwarding)
- **Authentication**: OAuth2 Proxy + Keycloak for protected apps

### Troubleshooting Resources
- `notes/docs/operations/cluster-maintenance.md` - Operational procedures
- `scripts/README.md` - Script documentation
- Individual service READMEs in `notes/docs/services/<service>/README.md`
