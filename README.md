# Fako Cluster - K3s HomeLab

A production-grade Kubernetes homelab running on K3s, managed through GitOps with FluxCD. This cluster combines enterprise patterns with homelab flexibility, featuring GPU-accelerated AI/ML workloads, comprehensive monitoring, and automated operations.

## Table of Contents
- [Overview](#overview)
- [Hardware Infrastructure](#hardware-infrastructure)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Applications](#applications)
- [Infrastructure Components](#infrastructure-components)
- [Security & Secret Management](#security--secret-management)
- [Monitoring & Observability](#monitoring--observability)
- [Storage Architecture](#storage-architecture)
- [Backup Strategy](#backup-strategy)
- [Development Environment](#development-environment)
- [Deployment Guide](#deployment-guide)
- [Maintenance & Operations](#maintenance--operations)

## Overview

This cluster represents a sophisticated homelab implementation that bridges the gap between personal projects and production-grade infrastructure. It's designed with several key principles:

- **GitOps-First**: All changes are made through Git, with FluxCD ensuring the cluster state matches the repository
- **Security by Design**: No sensitive data in Git, all secrets managed through AWS Secrets Manager
- **Multi-Environment Support**: Separate dev and production environments with resource-appropriate configurations
- **GPU Acceleration**: Dedicated GPU node for AI/ML workloads with proper scheduling and resource management
- **Comprehensive Monitoring**: Full observability stack with Prometheus, Loki, and Grafana
- **Automated Operations**: Self-updating dependencies, automated backups, and security scanning

## Hardware Infrastructure

The cluster runs on a heterogeneous mix of hardware, optimized for different workload types:

| Node | Role | CPU | Memory | Storage | GPU | Purpose |
|------|------|-----|---------|---------|-----|---------|
| **yeezyai** | GPU Worker | 24 cores | 32GB | 957GB | 2x NVIDIA | AI/ML workloads, LLM inference |
| **zz-macbookpro** | Control Plane | 12 cores | 16GB | 479GB | - | Cluster management, lightweight apps |
| **thinkpad01** | Worker | 8 cores | 16GB | 102GB | - | General workloads |
| **pgmac01** | Worker | 4 cores | 8GB | 102GB | - | Distributed services |
| **pgmac02** | Worker | 4 cores | 8GB | 102GB | - | Distributed services |
| **pglenovo01** | Worker | 4 cores | 8GB | 100GB | - | Distributed services |
| **pglenovo02** | Worker | 4 cores | 8GB | 119GB | - | Distributed services |

**External Storage**: Synology NAS providing NFS shares for persistent storage

## Architecture

### GitOps Flow
```
GitHub Repository (fako-cluster)
         ↓
    Flux Source Controller
         ↓
    Kustomize Controller
         ↓
    Helm Controller
         ↓
Kubernetes Resources (Apps, Config, Secrets)
```

### Repository Structure
```
fako-cluster/
├── apps/                    # Application deployments
│   ├── base/               # Base configurations (environment-agnostic)
│   ├── dev/                # Development overlays
│   └── staging/            # Production overlays
├── clusters/               # Cluster bootstrapping
│   ├── dev/                # Dev cluster configuration
│   └── staging/            # Production cluster configuration
├── infrastructure/         # Platform components
│   ├── configs/            # Infrastructure configuration
│   └── controllers/        # Operators and controllers
└── monitoring/             # Observability stack
    ├── configs/            # Monitoring configuration
    └── controllers/        # Monitoring operators
```

## Technology Stack

### Core Platform
- **Kubernetes Distribution**: K3s (lightweight, perfect for edge/homelab)
- **GitOps**: FluxCD v2 (source, kustomize, helm, notification controllers)
- **Service Mesh**: Traefik (built into K3s)
- **Container Runtime**: containerd with NVIDIA runtime support

### Infrastructure Components
- **Secret Management**: External Secrets Operator + AWS Secrets Manager
- **Certificate Management**: cert-manager (for internal TLS)
- **Storage**: NFS CSI Driver + Dynamic Provisioning
- **Database**: CloudNative-PG (PostgreSQL operator)
- **GPU Support**: NVIDIA GPU Operator

### Observability
- **Metrics**: Prometheus + Grafana
- **Logs**: Loki + Promtail/Alloy
- **Traces**: OpenTelemetry (via Alloy)
- **Dashboards**: Grafana with custom dashboards

## Applications

### AI/ML Stack

#### Ollama
- **Purpose**: Large Language Model inference server
- **Deployment**: GPU-accelerated on dedicated node
- **Models**: Multiple models including Llama, Mistral, Gemma variants
- **Access**: Internal API on port 11434, NodePort 31434
- **Storage**: 200GB for model storage
- **Features**: 
  - Automatic model management
  - GPU memory optimization
  - Multi-model support

#### Ollama WebUI
- **Purpose**: Chat interface for LLMs
- **Backend**: Integrates with GPUStack for additional models
- **Features**: 
  - Multi-model chat interface
  - Conversation history
  - Model switching
- **Access**: https://ai.yourdomain.com

#### Voice Assistant Pipeline
A complete voice assistant system using Wyoming protocol:

- **Whisper** (Speech-to-Text)
  - GPU-accelerated transcription
  - Multiple model sizes (tiny for speed, base for accuracy)
  - Wyoming protocol on port 10300
  
- **Piper** (Text-to-Speech)
  - High-quality neural TTS
  - Multiple voice options
  - Auto-scaling based on load
  - Wyoming protocol on port 10200
  
- **OpenWakeWord**
  - Wake word detection (Alexa, Hey Jarvis, etc.)
  - Low-latency activation
  - Wyoming protocol on port 10400

### Web Applications

#### Audiobookshelf
- **Purpose**: Audiobook and podcast server
- **Features**: 
  - Web-based player
  - Progress syncing
  - Multiple user support
  - Mobile app support
- **Storage**: Separate volumes for config, metadata, and media

#### Linkding
- **Purpose**: Bookmark manager
- **Features**: 
  - Tag-based organization
  - Full-text search
  - Import/export
  - REST API
- **Access**: Via Cloudflare tunnel

#### PGAdmin
- **Purpose**: PostgreSQL management
- **Features**: 
  - Multi-server support
  - Query tool
  - Backup/restore
- **Integration**: Auto-configured for cluster databases

### Identity & Access Management

#### Keycloak
- **Purpose**: Enterprise-grade identity provider
- **Version**: 26.x
- **Features**: 
  - OIDC/SAML support
  - User federation
  - Multi-realm support
  - HA deployment (2 replicas)
- **Integration**: SSO for all cluster applications

### Health & Fitness

#### Oura Ring Integration
- **Collector**: Automated data collection from Oura API
- **Dashboard**: Custom Streamlit dashboard for data visualization
- **Features**: 
  - Sleep analysis
  - Activity tracking
  - Readiness scores
  - Historical trends
- **Storage**: PostgreSQL with time-series optimization

#### Wger
- **Purpose**: Workout and nutrition manager
- **Features**: 
  - Exercise database
  - Workout planning
  - Progress tracking
  - REST API
- **Components**: Web app, Redis cache, Celery workers

### Security & Maintenance

#### Gitleaks
- **Purpose**: Secret scanning and prevention
- **Features**: 
  - Scheduled repository scanning
  - Git history cleaning with BFG
  - Automated remediation
  - Slack notifications
- **Schedule**: Every 6 hours

#### Renovate
- **Purpose**: Automated dependency updates
- **Features**: 
  - Helm chart updates
  - Container image updates
  - Kubernetes manifest updates
  - Grouped updates by type
- **Schedule**: Hourly checks

## Infrastructure Components

### External Secrets Operator
Manages all sensitive data through AWS Secrets Manager:
- Database credentials
- API keys
- OAuth secrets
- Internal service endpoints

**Pattern**: Each namespace has its own SecretStore with scoped AWS IAM permissions

### CloudNative-PG
Production-grade PostgreSQL:
- 3-node HA cluster
- Automated backups
- Point-in-time recovery
- Connection pooling
- Monitoring integration

### NFS Storage
Dynamic storage provisioning without hardcoded IPs:
- **StorageClasses**: 
  - `nfs-csi-v2`: General purpose
  - `nfs-postgres-v2`: Database optimized
  - `nfs-backup`: Backup storage
- **Implementation**: Dynamic job creates StorageClasses from AWS Secrets

### GPU Operator
NVIDIA GPU support:
- Automatic driver validation
- Device plugin for scheduling
- DCGM metrics exporter
- Container runtime configuration
- MIG support (if available)

## Security & Secret Management

### Zero-Trust Secrets
No sensitive data in Git repository:

1. **AWS Secrets Manager**: Central secret storage
2. **External Secrets Operator**: Syncs secrets to Kubernetes
3. **SOPS Encryption**: AWS credentials encrypted in Git
4. **Dynamic Configuration**: IPs and endpoints from secrets

### Network Security
- **Ingress**: Traefik with automatic TLS
- **External Access**: Cloudflare tunnels for select services
- **Internal**: Network policies for pod-to-pod communication
- **Authentication**: OAuth2 proxy with Keycloak

### RBAC
- Minimal privilege principle
- Service accounts for all workloads
- Namespace isolation
- Audit logging enabled

## Monitoring & Observability

### Metrics Stack
- **Prometheus**: 30-day retention, 50GB storage
- **Grafana**: Custom dashboards for all services
- **Exporters**: Node, GPU, PostgreSQL, custom app metrics
- **Alerts**: Critical infrastructure and application alerts

### Logging Stack
- **Loki**: Distributed mode, 31-day retention
- **Alloy**: Modern telemetry collector
- **Sources**: Container logs, system logs, application logs
- **Features**: LogQL queries, Grafana integration

### Custom Monitoring
- **Voice Pipeline Monitor**: Real-time status dashboard
- **GPU Metrics**: Utilization, memory, temperature, power
- **Backup Status**: Job success/failure tracking

## Storage Architecture

### Dynamic NFS Configuration
Revolutionary approach to storage configuration:
- No hardcoded IPs in any configuration
- NFS server details stored in AWS Secrets Manager
- Kubernetes Job dynamically creates StorageClasses
- Complete GitOps compatibility

### Storage Tiers
1. **Performance** (SSD-backed NFS)
   - Database storage
   - Application state
   
2. **Capacity** (HDD-backed NFS)
   - Media files
   - Model storage
   - Backups

3. **Local** (Node storage)
   - Temporary data
   - Cache

## Backup Strategy

### Automated Backups
Three-tier backup approach:

1. **Daily Backups** (2 AM)
   - All Kubernetes resources
   - Application configurations
   - 30-day retention

2. **ETCD Backups** (2:30 AM)
   - Cluster state snapshots
   - Disaster recovery capability

3. **Weekly Full Backups** (Sundays 3 AM)
   - Complete cluster state
   - Persistent volume data
   - Extended retention

### Backup Storage
```
/backups/
├── daily/
│   └── YYYYMMDD-HHMMSS/
├── weekly/
│   └── YYYYMMDD-HHMMSS/
└── etcd/
    └── YYYYMMDD-HHMMSS/
```

## Development Environment

### CPU-Only Development
Complete stack without GPU requirements:
- **Ollama**: CPU mode with small models (tinyllama, phi3)
- **Whisper**: INT8 optimized for CPU
- **Same Architecture**: Identical service structure as production

### Benefits
- Local development without expensive hardware
- Full integration testing
- Reduced resource consumption
- Faster iteration cycles

## Deployment Guide

### Prerequisites
- K3s cluster (3+ nodes recommended)
- NFS server
- AWS account for Secrets Manager
- GitHub account
- Domain name (optional)

### Quick Start
```bash
# 1. Fork and clone
git clone https://github.com/yourusername/fako-cluster
cd fako-cluster

# 2. Create age key for SOPS
age-keygen -o age.agekey

# 3. Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# 4. Bootstrap Flux
flux bootstrap github \
  --owner=yourusername \
  --repository=fako-cluster \
  --branch=main \
  --path=clusters/staging

# 5. Create required secrets in AWS
# See individual app documentation
```

## Maintenance & Operations

### Daily Tasks
- Monitor cluster health via Grafana
- Review Renovate PRs
- Check backup status

### Common Operations
```bash
# Check cluster status
flux get all -A

# Force reconciliation
flux reconcile source git flux-system

# View logs
flux logs --follow

# Check GPU status
kubectl exec -n gpu-operator -it $(kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset -o jsonpath='{.items[0].metadata.name}') -- nvidia-smi
```

### Troubleshooting
1. **Application Issues**: Check Flux events and pod logs
2. **Storage Issues**: Verify NFS connectivity test job
3. **GPU Issues**: Check GPU operator and device plugin logs
4. **Secret Issues**: Verify External Secrets Operator status

## Philosophy

This cluster embodies several key principles:

1. **Everything as Code**: No manual changes, everything through Git
2. **Security First**: No secrets in Git, defense in depth
3. **Observability**: If you can't measure it, you can't improve it
4. **Automation**: Humans shouldn't do what machines can do better
5. **Learning Platform**: Every component is an opportunity to learn

## About

**Created by**: Landry  
*"A mechanical engineer by training, I enjoy tearing things down and rebuilding them. This cluster is my digital workshop - a place to understand how modern infrastructure works and how it can be improved."*

---

This cluster demonstrates that homelab infrastructure can be both a learning platform and production-grade system. It's proof that with the right patterns and tools, you can run enterprise-level infrastructure on consumer hardware.
