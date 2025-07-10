# Fako Cluster - K3s HomeLab Documentation

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Infrastructure Components](#infrastructure-components)
- [Applications](#applications)
- [Monitoring Stack](#monitoring-stack)
- [Storage Configuration](#storage-configuration)
- [GPU Support](#gpu-support)
- [Security](#security)
- [Backup Strategy](#backup-strategy)
- [Deployment Guide](#deployment-guide)
- [Maintenance](#maintenance)

## Overview

This is a K3s-based Kubernetes homelab cluster managed through GitOps with FluxCD. The cluster features a comprehensive monitoring stack, GPU support for AI/ML workloads, automated backups, and various self-hosted applications.

**Key Features:**
- GitOps-driven deployment with FluxCD
- Multi-node K3s cluster with GPU support
- NFS-based persistent storage
- PostgreSQL database cluster with CloudNative PG
- Comprehensive monitoring with Prometheus, Loki, and Grafana
- Voice assistant pipeline with Whisper, Piper, and OpenWakeWord
- Automated dependency updates with Renovate
- Secret management with AWS Secrets Manager and SOPS

## Architecture

### Cluster Topology
```
┌─────────────────────────────────────────────────────────────┐
│                        Git Repository                        │
│                   (github.com/lyzetam/fako-cluster)         │
└──────────────────────────┬──────────────────────────────────┘
                           │ FluxCD Sync
┌──────────────────────────▼──────────────────────────────────┐
│                      K3s Cluster                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Control Plane │  │  Worker Nodes   │  │  GPU Node   │ │
│  │                 │  │                 │  │  (yeezyai)  │ │
│  │  - zzmbp        │  │  - pgmac01      │  │             │ │
│  │                 │  │  - pgmac02      │  │  RTX 5070   │ │
│  │                 │  │  - pglenovo01   │  │  RTX 3050   │ │
│  │                 │  │  - pglenovo02   │  │             │ │
│  │                 │  │  - thinkpad01   │  │             │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    External Storage                         │
│                  Synology NAS (NFS Server)                  │
│  - General storage                                          │
│  - Database storage                                         │
│  - Backup storage                                           │
└─────────────────────────────────────────────────────────────┘
```

### GitOps Structure
```
fako-cluster/
├── apps/                    # Application deployments
│   ├── base/               # Base configurations
│   └── staging/            # Environment-specific overlays
├── clusters/               # Cluster configurations
│   └── staging/            # Staging cluster setup
├── infrastructure/         # Infrastructure components
│   └── controllers/        # Operators and controllers
└── monitoring/             # Monitoring stack
    ├── configs/            # Monitoring configurations
    └── controllers/        # Monitoring operators
```

## Infrastructure Components

### Core Infrastructure

#### FluxCD
- **Version**: Latest
- **Components**: Source Controller, Kustomize Controller, Helm Controller
- **Purpose**: GitOps continuous delivery

#### External Secrets Operator
- **Version**: ^0.10.0
- **Integration**: AWS Secrets Manager
- **Purpose**: Secure secret management

#### CloudNative PG
- **Version**: ^0.24.0
- **Purpose**: PostgreSQL cluster management
- **Configuration**: 3-node cluster with 50GB storage

#### NFS CSI Driver
- **Version**: ^4.8.0
- **Storage Classes**:
  - `nfs-csi-v2`: General purpose storage
  - `nfs-postgres-v2`: Optimized for PostgreSQL
  - `nfs-backup`: Dedicated backup storage

#### NVIDIA GPU Operator
- **Purpose**: GPU device plugin and container runtime
- **Features**: 
  - Driver validation disabled (pre-installed drivers)
  - DCGM metrics exporter
  - Container toolkit with K3s integration

## Applications

### Web Applications

#### Linkding
- **Purpose**: Bookmark manager
- **Access**: Via Cloudflare tunnel
- **Storage**: 500Mi persistent volume
- **Features**: Self-hosted bookmark management with tagging

#### Audiobookshelf
- **Purpose**: Audiobook and podcast server
- **Port**: 3005
- **Storage**: 
  - Config: 1Gi
  - Metadata: 5Gi
  - Audiobooks: 5Gi
- **Access**: Via Cloudflare tunnel

#### Home Assistant (Homebot)
- **Purpose**: Home automation platform
- **Port**: 8123
- **Storage**: 5Gi for configuration
- **Features**: Reverse proxy support, timezone configuration

### AI/ML Stack

#### Ollama
- **Deployment**: GPU-enabled on dedicated node
- **GPU**: RTX 5070 (primary)
- **Storage**: 200Gi for models
- **Models**: Multiple LLMs including Llama, Gemma, Mistral
- **Access**: NodePort 31434

#### Ollama WebUI
- **Purpose**: Web interface for Ollama
- **Integration**: GPUStack backend
- **Storage**: 5Gi for chat history
- **Access**: ai.landryzetam.net

#### Voice Pipeline Components

**Whisper (Speech-to-Text)**
- **GPU**: RTX 3050 or RTX 5070
- **Model**: Tiny (optimized for speed)
- **Port**: 10300 (Wyoming protocol)
- **Storage**: 10Gi for models

**Piper (Text-to-Speech)**
- **Voices**: Multiple English voices
- **Port**: 10200 (Wyoming protocol)
- **Storage**: 15Gi for voice models
- **Features**: Auto-scaling with HPA

**OpenWakeWord**
- **Wake words**: alexa, hey_jarvis, hey_mycroft, ok_nabu
- **Port**: 10400 (Wyoming protocol)
- **Storage**: 5Gi for models

### Identity & Access Management

#### Keycloak
- **Version**: 26.3.0
- **Deployment**: HA with 2 replicas
- **Database**: PostgreSQL (managed)
- **Access**: subdomain.landryzetam.net
- **Features**: 
  - OIDC/SAML support
  - Kubernetes clustering
  - External Secrets integration

### Health & Fitness

#### Oura Collector
- **Purpose**: Collect data from Oura Ring API
- **Storage**: PostgreSQL + 10Gi volume
- **Schedule**: Hourly collection
- **Features**: AWS Secrets Manager integration

#### Oura Dashboard
- **Purpose**: Streamlit dashboard for Oura data
- **Port**: 8501
- **Authentication**: OAuth2 Proxy with Keycloak
- **Access**: Via Cloudflare tunnel

#### Wger
- **Purpose**: Workout manager
- **Chart Version**: 0.2.4
- **Features**: 
  - Exercise tracking
  - Redis caching
  - Celery workers
- **Access**: subdomain.landryzetam.net

### Security & Maintenance

#### Gitleaks Scanner
- **Schedule**: Every 6 hours
- **Features**: 
  - Automated secret detection
  - BFG integration for cleanup
  - Slack notifications

#### Renovate
- **Schedule**: Hourly
- **Purpose**: Automated dependency updates
- **Target**: lyzetam/fako-cluster repository

## Monitoring Stack

### Prometheus Stack
- **Chart**: kube-prometheus-stack ^66.2.0
- **Components**:
  - Prometheus (30d retention, 50Gi storage)
  - Grafana
  - AlertManager
  - Node Exporter
  - kube-state-metrics
- **Access**: grafana.landryzetam.net

### Loki Stack
- **Version**: 6.30.1
- **Mode**: Distributed (3 write replicas)
- **Storage**: Filesystem-based
- **Retention**: 31 days
- **Components**: Write path, Read path, Backend, Gateway

### Grafana Alloy
- **Purpose**: Telemetry collection pipeline
- **Features**:
  - Kubernetes pod log collection
  - Service discovery
  - Loki log forwarding
  - Self-monitoring

### GPU Monitoring
- **Exporter**: nvidia_gpu_exporter
- **Port**: 9835
- **Metrics**: Utilization, memory, temperature, power
- **Deployment**: DaemonSet on GPU nodes

### Voice Pipeline Monitor
- **Purpose**: Custom monitoring dashboard
- **Features**: Real-time component status
- **Access**: voice-monitor.landryzetam.net

## Security

### Secret Management
1. **SOPS Encryption**
   - Age encryption for Git-stored secrets
   - Per-environment encryption keys

2. **AWS Secrets Manager**
   - Database credentials
   - API keys
   - OAuth credentials

3. **External Secrets Operator**
   - Automatic secret synchronization
   - Namespace-scoped SecretStores

### Credentials Management

#### AWS Credentials
AWS credentials for External Secrets Operator are managed through SOPS-encrypted secrets in environment-specific overlays:
- **Location**: `apps/{dev,staging}/<app-name>/aws-credentials-secret.yaml`
- **Encryption**: SOPS with Age

#### Application Patterns

**Example: GPUStack API Keys (ollama-webui)**
1. **Base Configuration** (`apps/base/ollama-webui/`)
   - `aws-secret-store.yaml`: Connects to AWS Secrets Manager
   - `external-secret-gpustack.yaml`: Pulls API key from AWS
   - `configmap.yaml`: Contains only non-sensitive configuration
   - `deployment.yaml`: Mounts secrets as environment variables

2. **Environment Overlays** (`apps/{dev,staging}/ollama-webui/`)
   - `aws-credentials-secret.yaml`: SOPS-encrypted AWS credentials
   - `kustomization.yaml`: Includes base + environment-specific resources

**Supported Applications**
- Keycloak: Database and admin credentials
- Ollama WebUI: GPUStack API keys
- Oura Dashboard: OAuth2 and AWS credentials
- PostgreSQL: Database credentials
- Wger: Application secrets

### Network Security
- **Ingress**: Traefik with TLS
- **Internal**: Cloudflare tunnels for select services
- **Authentication**: Keycloak for SSO, OAuth2 Proxy

### RBAC Configuration
- Service accounts for all components
- Minimal privilege principle
- Namespace isolation

## Backup Strategy

### Automated Backups
1. **Kubernetes Resources**
   - **Schedule**: Daily at 2 AM
   - **Retention**: 30 days
   - **Scope**: All namespaces, cluster resources

2. **ETCD Backups**
   - **Schedule**: Daily at 2:30 AM
   - **Type**: Snapshots
   - **Storage**: NFS backup volume

3. **Weekly Comprehensive**
   - **Schedule**: Sundays at 3 AM
   - **Includes**: All resources + PVC data

### Backup Structure
```
backups/
├── daily/
│   └── YYYYMMDD-HHMMSS/
│       ├── namespaces/
│       ├── cluster/
│       └── backup-info.txt
├── weekly/
│   └── YYYYMMDD-HHMMSS/
└── etcd/
    └── YYYYMMDD-HHMMSS/
        └── etcd-snapshot.db
```

## Deployment Guide

### Prerequisites
1. K3s cluster with:
   - Minimum 3 nodes
   - NVIDIA drivers (for GPU node)
   - NFS server access
   
2. Tools:
   - kubectl
   - flux CLI
   - sops
   - age (for encryption)

### Initial Setup

1. **Fork and Clone Repository**
```bash
git clone https://github.com/lyzetam/fako-cluster
cd fako-cluster
```

2. **Configure Environment**
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
# - NFS_SERVER_IP
# - POSTGRES_HOST
# - Other environment-specific values
```

3. **Create Age Key**
```bash
age-keygen -o age.agekey
export SOPS_AGE_KEY_FILE="$PWD/age.agekey"
```

4. **Bootstrap FluxCD**
```bash
flux bootstrap github \
  --owner=YOUR_GITHUB_USER \
  --repository=fako-cluster \
  --branch=main \
  --path=clusters/staging \
  --personal
```

5. **Configure AWS Credentials**
```bash
# Create the secret using SOPS
sops infrastructure/secrets/aws-credentials.yaml
```

6. **Create Required Secrets in AWS**
- `postgres/admin-credentials`
- `postgres/app-user`
- `keycloak/admin-credentials`
- `auth-service/super-user`
- `oura/api-credentials`
- `wger/db-credentials`
- `gpustack/api-key` (key: OPENAI_API_KEYS)

### Verify Deployment

```bash
# Check FluxCD status
flux get all

# Check applications
kubectl get helmreleases -A

# Check pods
kubectl get pods -A

# Check storage
kubectl get pvc -A
```

## Maintenance

### Daily Operations

1. **Monitor Cluster Health**
```bash
kubectl top nodes
kubectl top pods -A
```

2. **Check Backup Status**
```bash
kubectl get cronjobs -n backup-system
kubectl logs -n backup-system -l job-name=k8s-backup-daily
```

3. **Review Renovate Updates**
- Check GitHub PRs for dependency updates
- Review and merge after testing

### GPU Management

1. **Check GPU Status**
```bash
kubectl exec -n gpu-operator $(kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset -o name | head -1) -- nvidia-smi
```

2. **Monitor GPU Metrics**
- Access Grafana dashboard
- Check GPU utilization and temperature

### Troubleshooting

1. **FluxCD Issues**
```bash
flux logs --follow
flux reconcile source git flux-system
```

2. **Storage Issues**
```bash
# Test NFS connectivity
kubectl apply -f infrastructure/controllers/base/nfs-storage/nfs-connectivity-test.yaml
kubectl logs -n nfs-system job/nfs-connectivity-test
```

3. **Application Issues**
```bash
# Check specific app
kubectl describe helmrelease APP_NAME -n NAMESPACE
kubectl logs -n NAMESPACE deployment/APP_NAME
```

## Additional Resources

- **Repository**: [github.com/lyzetam/fako-cluster](https://github.com/lyzetam/fako-cluster)
- **FluxCD Documentation**: [fluxcd.io](https://fluxcd.io)
- **K3s Documentation**: [k3s.io](https://k3s.io)

# GPU/CPU Architecture for Dev vs Production

## Current State (After Implementation)

### Production/Staging Environment
- **GPU-optimized services**: ollama, whisper (using GPU hardware)
- **CPU services**: piper, openwakeword (already CPU-based)
- **UI services**: ollama-webui, voice-monitor
- **GPU Hardware**: RTX 5070 on yeezyai node

### Development Environment
- **CPU versions**: ollama (CPU mode), whisper (CPU mode)
- **CPU services**: piper, openwakeword (same as prod)
- **UI services**: ollama-webui, voice-monitor
- **No GPU required**: All services run on CPU

## Architecture Pattern

### Services by Type

#### GPU-Optimized (Production) / CPU-Mode (Dev)
- `ollama`: 
  - **Prod**: GPU-accelerated LLM inference on RTX 5070
  - **Dev**: CPU-only with small models (tinyllama, phi3:mini)
- `whisper`:
  - **Prod**: GPU-accelerated speech-to-text
  - **Dev**: CPU-optimized with int8 compute type

#### CPU-Based (Same in Both Environments)
- `piper`: Text-to-speech (CPU-based)
- `openwakeword`: Wake word detection (CPU-based)

#### UI Services (No Compute Required)
- `ollama-webui`: Web interface (connects to GPUStack backend)
- `voice-monitor`: Monitoring dashboard

## Implementation Details

### Dev CPU Patches
1. **ollama**: `apps/dev/ollama/deployment-cpu-patch.yaml`
   - Removes GPU node selector, tolerations, and runtime
   - Sets `OLLAMA_GPU_LAYERS=0` to force CPU
   - Reduces resource limits
   - Downloads only small CPU-friendly models

2. **whisper**: `apps/dev/whisper/deployment-cpu-patch.yaml`
   - Uses CPU-optimized whisper image
   - Sets compute type to int8 for CPU efficiency
   - Removes GPU-specific configurations

## Benefits
- **Full Stack Testing**: Developers can test the complete AI/ML stack locally
- **No GPU Required**: All services run on CPU in dev environment
- **Resource Efficient**: CPU versions use minimal resources
- **Consistent Architecture**: Same service structure in dev and prod

# Ollama WebUI - External Secrets Configuration

This application uses AWS Secrets Manager to store sensitive configuration data, including internal IP addresses and API keys.

## Required AWS Secrets

### 1. GPUStack API Key
- **Secret Name**: `gpustack/api-key`
- **Secret Value**: JSON object with the following structure:
```json
{
  "OPENAI_API_KEYS": "your-gpustack-api-key-here"
}
```

### 2. Endpoint URLs
- **Secret Name**: `ollama-webui/endpoints`
- **Secret Value**: JSON object with the following structure:
```json
{
  "gpustack_base_url": "http://YOUR-INTERNAL-IP:80/v1-openai"
}
```

## Setup Instructions

1. **Create the secret in AWS Secrets Manager** (one-time setup):
```bash
# Create endpoints secret in AWS (replace with your actual internal IP)
aws secretsmanager create-secret \
  --name ollama-webui/endpoints \
  --secret-string '{"gpustack_base_url":"http://10.85.35.223:80/v1-openai"}'
```

2. **Deploy to Kubernetes**:
```bash
# The External Secrets Operator will automatically:
# - Use the existing aws-credentials secret (managed by SOPS) to authenticate
# - Fetch the secret from AWS Secrets Manager
# - Create the Kubernetes secret with the endpoint URLs
kubectl apply -k apps/base/ollama-webui/
```

3. **Verify the secret is created**:
```bash
# Check External Secret status
kubectl get externalsecret -n ollama-webui endpoints-secret

# Verify the Kubernetes secret was created
kubectl get secret -n ollama-webui ollama-endpoints
```

## Architecture

The application uses the following External Secrets:
- `external-secret-gpustack.yaml`: Fetches API keys from AWS
- `external-secret-endpoints.yaml`: Fetches endpoint URLs from AWS

These secrets are mounted into the deployment via `envFrom` in the following order:
1. ConfigMap (`ollama-webui-configmap`)
2. GPUStack credentials secret
3. Endpoint URLs secret

## Benefits

- No hardcoded IPs or sensitive data in the Git repository
- Centralized secret management via AWS Secrets Manager
- Easy rotation of credentials and endpoints
- Follows GitOps best practices

# Ollama WebUI - External Secrets Configuration

This application uses AWS Secrets Manager to store sensitive configuration data, including internal IP addresses and API keys.

## Required AWS Secrets

### 1. GPUStack API Key
- **Secret Name**: `gpustack/api-key`
- **Secret Value**: JSON object with the following structure:
```json
{
  "OPENAI_API_KEYS": "your-gpustack-api-key-here"
}
```

### 2. Endpoint URLs
- **Secret Name**: `ollama-webui/endpoints`
- **Secret Value**: JSON object with the following structure:
```json
{
  "gpustack_base_url": "http://YOUR-INTERNAL-IP:80/v1-openai"
}
```

## Setup Instructions

### 1. Create the secret in AWS Secrets Manager (one-time setup):
```bash
# Create endpoints secret in AWS (replace with your actual internal IP)
aws secretsmanager create-secret \
  --name ollama-webui/endpoints \
  --secret-string '{"gpustack_base_url":"http://10.85.35.223:80/v1-openai"}'
```

### 2. Update IAM Policy for External Secrets User
The `external-secrets-user` IAM user needs permission to access the new secret. Add this to the user's policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:584144127892:secret:gpustack/api-key*",
        "arn:aws:secretsmanager:us-east-1:584144127892:secret:ollama-webui/endpoints*"
      ]
    }
  ]
}
```

### 3. Deploy to Kubernetes:
```bash
# The External Secrets Operator will automatically:
# - Use the existing aws-credentials secret (managed by SOPS) to authenticate
# - Fetch the secret from AWS Secrets Manager
# - Create the Kubernetes secret with the endpoint URLs
kubectl apply -k apps/base/ollama-webui/
```

### 4. Verify the secret is created:
```bash
# Check External Secret status
kubectl get externalsecret -n ollama-webui endpoints-secret

# Verify the Kubernetes secret was created
kubectl get secret -n ollama-webui ollama-endpoints
```

## Architecture

The application uses the following External Secrets:
- `external-secret-gpustack.yaml`: Fetches API keys from AWS
- `external-secret-endpoints.yaml`: Fetches endpoint URLs from AWS

These secrets are mounted into the deployment via `envFrom` in the following order:
1. ConfigMap (`ollama-webui-configmap`)
2. GPUStack credentials secret
3. Endpoint URLs secret (marked as optional until AWS permissions are configured)

## Troubleshooting

If you see `SecretSyncedError` on the External Secret:
1. Check the IAM policy for the external-secrets-user
2. Ensure the secret exists in AWS Secrets Manager
3. Check the External Secret logs: `kubectl describe externalsecret -n ollama-webui endpoints-secret`

## Benefits

- No hardcoded IPs or sensitive data in the Git repository
- Centralized secret management via AWS Secrets Manager
- Easy rotation of credentials and endpoints
- Follows GitOps best practices



## About

**Maintainer**: Landry  
*"A mechanical engineer by training. I enjoy tearing things down and rebuilding them, always eager to understand how things work and how they can be improved."*

---

This cluster represents a comprehensive homelab setup combining traditional web applications with modern AI/ML capabilities, all managed through GitOps principles for reproducibility and ease of maintenance.
