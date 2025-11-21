# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fako Cluster is a GitOps-managed Kubernetes homelab running on K3s with FluxCD. It hosts AI/ML workloads (Ollama, Whisper, Piper), productivity apps, and infrastructure services across heterogeneous hardware including GPU nodes (RTX 5070, RTX 3050) and ARM devices.

## Common Commands

### GitOps Deployment
```bash
# Deploy changes through GitOps (preferred method)
./scripts/gitops-deploy.sh

# Dry-run mode
./scripts/gitops-deploy.sh --dry-run
```

### Flux Operations
```bash
# Check all Flux resources
flux get all -A

# Force reconciliation
flux reconcile source git flux-system

# Reconcile specific kustomization
flux reconcile kustomization apps

# View Flux logs
flux logs --follow

# Check specific kustomization
flux logs --kind=Kustomization --name=apps
```

### Cluster Status
```bash
# Node and pod health
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
kubectl top nodes
kubectl top pods --all-namespaces

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
No secrets in Git. Each namespace follows:
1. AWS Secrets Manager holds secret values
2. `SecretStore` configured per namespace with scoped IAM permissions
3. `ExternalSecret` syncs specific secrets to Kubernetes

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

## Hardware Context
- **yeezyai**: GPU worker (Ryzen 9, 32GB, dual NVIDIA GPUs)
- **zz-macbookpro**: Control plane (M1 Pro)
- **thinkpad01, pgmac01/02, pglenovo01/02**: Worker nodes
- **UGREEN NAS**: 12TB NFS storage
