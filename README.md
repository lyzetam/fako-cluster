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

## About

**Maintainer**: Landry  
*"A mechanical engineer by training. I enjoy tearing things down and rebuilding them, always eager to understand how things work and how they can be improved."*

---

This cluster represents a comprehensive homelab setup combining traditional web applications with modern AI/ML capabilities, all managed through GitOps principles for reproducibility and ease of maintenance.