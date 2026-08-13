# Fako Cluster: Production-Grade Kubernetes Homelab

![Kubernetes](https://img.shields.io/badge/Kubernetes-K3s-326CE5?logo=kubernetes&logoColor=white)
![GitOps](https://img.shields.io/badge/GitOps-FluxCD-5468FF?logo=flux&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Kustomize-326CE5?logo=kubernetes&logoColor=white)
![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazonaws&logoColor=white)
![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus&logoColor=white)
![GPU](https://img.shields.io/badge/GPU-NVIDIA-76B900?logo=nvidia&logoColor=white)

> A fully automated, GitOps-managed Kubernetes platform running 40+ microservices across 7 heterogeneous nodes, demonstrating enterprise infrastructure patterns at home scale.

## Key Metrics

| Metric | Value |
|--------|-------|
| **Deployed Applications** | 40+ containerized services |
| **Cluster Nodes** | 7 (mixed x86_64 + ARM64 + Apple Silicon) |
| **GPU Compute** | Dual NVIDIA GPUs (RTX 5070 + RTX 3050) |
| **Storage Backend** | 12TB NAS with dynamic provisioning |
| **Uptime Target** | Self-healing with automated reconciliation |
| **Deployment Method** | 100% GitOps (zero manual kubectl apply) |

---

## Skills Demonstrated

### Platform Engineering & Kubernetes
- **Container Orchestration**: K3s cluster management, multi-architecture support (amd64/arm64)
- **GitOps & CI/CD**: FluxCD for continuous deployment, drift detection, automated reconciliation
- **Infrastructure as Code**: Kustomize overlays, Helm charts, declarative configuration
- **Storage**: CSI drivers (NFS, SMB), dynamic provisioning, persistent volume management
- **Networking**: Ingress controllers (Traefik), service mesh concepts, DNS management

### Cloud & Security
- **AWS Integration**: Secrets Manager, IAM policies, External Secrets Operator
- **Identity Management**: Keycloak (OIDC/SAML), OAuth2 Proxy, SSO implementation
- **Zero-Trust Security**: Cloudflare Tunnels, network policies, secret encryption (SOPS)
- **TLS/PKI**: Cert-Manager with Let's Encrypt, automated certificate rotation

### Database & Data Engineering
- **PostgreSQL Operations**: CloudNative-PG operator, 3-node HA clusters, automated backups
- **Data Pipelines**: ETL processes, API integrations, scheduled jobs (CronJobs)
- **Backup & Recovery**: Velero, point-in-time recovery, disaster recovery planning

### AI/ML Infrastructure
- **GPU Workloads**: NVIDIA GPU Operator, multi-GPU scheduling, CUDA container runtime
- **LLM Deployment**: Ollama, model serving, inference optimization
- **Voice AI Pipeline**: Whisper (STT), Piper (TTS), OpenWakeWord, Home Assistant integration

### Observability
- **Metrics**: Prometheus, custom ServiceMonitors, alerting rules
- **Logging**: Loki (distributed mode), log aggregation, retention policies
- **Visualization**: Grafana dashboards, OpenTelemetry integration

### DevOps Practices
- **Automated Updates**: Renovate bot for dependency management
- **Version Control**: Git workflows, branch strategies, PR automation
- **Documentation**: Infrastructure documentation, runbooks, operational procedures

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL ACCESS                                 │
│  Cloudflare Tunnels (Zero-Trust) ──► Traefik Ingress ──► Let's Encrypt TLS │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
┌─────────────────────────────────────────────────────────────────────────────┐
│                               GITOPS LAYER                                   │
│  GitHub ──► FluxCD Source Controller ──► Kustomize/Helm ──► K8s API        │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
┌─────────────────────────────────────────────────────────────────────────────┐
│                            APPLICATION LAYER                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   AI/ML      │  │  Databases   │  │   Identity   │  │  Monitoring  │    │
│  │  ─────────   │  │  ──────────  │  │  ──────────  │  │  ──────────  │    │
│  │  Ollama      │  │  PostgreSQL  │  │  Keycloak    │  │  Prometheus  │    │
│  │  Whisper     │  │  (HA Cluster)│  │  OAuth2 Proxy│  │  Loki        │    │
│  │  Piper       │  │  Redis       │  │              │  │  Grafana     │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INFRASTRUCTURE LAYER                               │
│  External Secrets ◄──► AWS Secrets Manager                                  │
│  NFS CSI Driver   ◄──► UGREEN NAS (12TB RAID5)                             │
│  GPU Operator     ◄──► NVIDIA Runtime (RTX 5070 + RTX 3050)                │
│  Cert-Manager     ◄──► Let's Encrypt                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
┌─────────────────────────────────────────────────────────────────────────────┐
│                              COMPUTE LAYER                                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ thinkpad02  │ │ zz-macbook  │ │ thinkpad01  │ │ pglenovo01  │  + 2 more │
│  │  Worker     │ │ Control Plane│ │  Wkr/Store │ │   Worker    │           │
│  │  i7-9750H   │ │  M1 Pro     │ │  i5-8250U  │ │  i5-6200U   │           │
│  │  32GB/WiFi  │ │   16GB      │ │    16GB    │ │     8GB     │           │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
fako-cluster/
├── apps/                           # Application deployments (40+ services)
│   ├── base/                       # Base Kustomize configurations
│   │   ├── ollama/                 # GPU-accelerated LLM inference
│   │   ├── keycloak/               # Identity provider (OIDC/SAML)
│   │   ├── paperless-ngx/          # Document management with OCR
│   │   └── ...                     # Each app: deployment, service, ingress, secrets
│   └── staging/                    # Production overlays and patches
│
├── infrastructure/
│   ├── controllers/                # Platform operators
│   │   └── base/
│   │       ├── external-secrets/   # AWS Secrets Manager integration
│   │       ├── gpu-operator/       # NVIDIA GPU support
│   │       ├── nfs-csi-driver/     # Dynamic storage provisioning
│   │       └── renovate/           # Automated dependency updates
│   └── configs/                    # Certificates, storage classes, secrets
│
├── monitoring/
│   ├── controllers/                # Prometheus, Loki, Grafana stack
│   └── configs/                    # Dashboards, alerting rules
│
└── clusters/staging/               # Flux bootstrap configuration
```

### GitOps Workflow

Every change follows the GitOps pattern:

1. **Commit** → Push manifest changes to GitHub
2. **Detect** → Flux Source Controller polls repository (1-min interval)
3. **Reconcile** → Kustomize/Helm controllers apply changes
4. **Verify** → Drift detection ensures desired state matches actual state

```bash
# Zero manual intervention required
git push origin main
# Flux automatically deploys within 60 seconds
```

---

## Technical Deep Dives

### Secret Management Architecture

Implemented enterprise-grade secret management with zero secrets in Git:

```yaml
# Pattern: AWS Secrets Manager → External Secrets Operator → Kubernetes Secrets
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-store      # Namespace-scoped with IAM policies
    kind: SecretStore
  target:
    name: db-secret
  data:
    - secretKey: password
      remoteRef:
        key: /fako/postgres/credentials
        property: password
```

**Security Controls:**
- SOPS encryption for AWS credentials in Git
- Namespace-scoped SecretStores with least-privilege IAM
- Automatic secret rotation support
- Audit logging via CloudTrail

### GPU Workload Scheduling

Dual-GPU system with workload-specific allocation:

| GPU | VRAM | Assigned Workloads |
|-----|------|-------------------|
| RTX 5070 | 12GB GDDR7 | LLM inference (Ollama), large models |
| RTX 3050 | 8GB | Speech-to-text (Whisper), smaller models |

```yaml
# GPU workload configuration
spec:
  runtimeClassName: nvidia
  nodeSelector:
    nvidia.com/gpu.present: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
  containers:
    - resources:
        limits:
          nvidia.com/gpu: 1
```

### High-Availability PostgreSQL

CloudNative-PG operator managing production-grade database clusters:

- **3-node HA cluster** with automatic failover
- **Streaming replication** with synchronous commits
- **Automated backups** to NFS with retention policies
- **Point-in-time recovery** capability
- **Connection pooling** via PgBouncer

### Observability Stack

Full observability implementation following the three pillars:

| Pillar | Tool | Configuration |
|--------|------|---------------|
| **Metrics** | Prometheus | 30-day retention, ServiceMonitor CRDs |
| **Logs** | Loki | Distributed mode, 31-day retention |
| **Traces** | OpenTelemetry | Alloy collector, Tempo backend |

---

## AI/ML Platform

### Local LLM Infrastructure

Privacy-focused AI infrastructure running entirely on-premises:

- **Ollama**: GPU-accelerated inference for Llama 3, Mistral, and other models
- **OpenWebUI**: Multi-user chat interface with conversation history
- **GPUStack**: Distributed inference across Apple Silicon nodes

### Voice AI Pipeline

Complete voice assistant replacing cloud services:

```
Voice Input → OpenWakeWord → Whisper (STT) → LLM → Piper (TTS) → Audio Output
     │              │             │           │          │
     └──────────────┴─────────────┴───────────┴──────────┘
                    All processing on local GPUs
```

**Integration**: Home Assistant voice control for smart home automation

---

## Infrastructure Specifications

### Compute Nodes

| Node | Role | CPU | Memory | Storage | Specialization |
|------|------|-----|--------|---------|----------------|
| **zz-macbookpro** | Control Plane | M1 Pro (12 cores) | 16GB | 479GB SSD | Cluster management |
| **thinkpad02** | Worker + GPU | i7-9750H (6c/12t) | 32GB | 954GB NVMe | Largest worker. **WiFi-only** (no NIC). GTX 1650 Mobile, 4GB — driver 595.84, `nvidia.com/gpu: 1` |
| **thinkpad01** | Worker + Storage | i5-8250U (8 cores) | 16GB | 102GB SSD | General workloads, `node-role.kubernetes.io/storage` |
| **pgmac01/02** | Workers | i5 (4 cores each) | 8GB each | 102GB SSD | Stateless services |
| **pglenovo01/02** | Workers | i5-6200U (4 cores each) | 8GB each | ~110GB SSD | Distributed load |

> **aitower** (Ryzen 9 3900X, 32GB, dual NVIDIA GPUs) left the cluster 2026-08-11. The GPU
> workloads pinned to it — `whisper`, `whisperx`, `parakeet`, `piper-v13`, `ollama` GPU —
> remain retired in `apps/staging/kustomization.yaml`.

#### thinkpad02 — added 2026-08-12

- **Hardware:** ThinkPad X1 Extreme 2nd Gen (20QV000DUS), Ubuntu 24.04, kernel 7.0.0-28
- **Network:** `10.85.30.8` over **WiFi** (`wlp82s0`) — this laptop has no Ethernet port.
  Joined via the `Fingerweg-Servers` SSID, created specifically to put VLAN 30 (Servers)
  on the air; it is 5 GHz / WPA2 / PMF-disabled and broadcasts on 5 of 6 APs (AP Upstairs
  was at its per-AP SSID limit). Config lives in `/etc/netplan/50-cloud-init.yaml`, with
  cloud-init network regeneration disabled.
- **Power:** lid-close and all sleep/suspend/hibernate targets are masked, so the node
  survives the lid being shut.
- **GPU:** GTX 1650 Mobile / Max-Q (TU117M, 4GB), driver **595.84**, CUDA runtime 13.2.
  `nvidia.com/gpu: 1` is allocatable and verified end-to-end — a pod requesting a GPU ran
  `nvidia-smi` inside a container and saw 3715 MiB free.

  **Secure Boot is enabled on this node**, so do *not* let the driver go in via DKMS — the
  unsigned module will not load. Install Canonical's pre-signed module instead, and use the
  HWE metapackage so it follows kernel upgrades rather than pinning to one kernel:

  ```bash
  sudo apt-get install -y linux-modules-nvidia-595-generic-hwe-24.04 nvidia-driver-595
  ```

  `nvidia-driver-595` depends on `nvidia-dkms-595 | linux-modules-nvidia-595-<flavour>`, so
  installing the pre-signed package first satisfies the alternative and skips DKMS entirely.
  `ubuntu-drivers devices` recommends the 595 branch for this GPU.

  **Known gap:** the `nvidia-gpu-exporter` DaemonSet in `gpu-monitoring` selects on
  `nvidia.com/gpu=true`, a label the GPU Operator does not set — GFD sets
  `nvidia.com/gpu.present=true`. It has been `DESIRED: 0` since aitower left and stays that
  way. Fix the selector, or label the node, if GPU metrics are wanted.

  **Sizing lesson — do not copy aitower's model configs onto this card.** TU117 has no
  tensor cores and only 4GB. Measured with a real transcription on 2026-08-12:

  | Config | Result |
  |---|---|
  | `distil-large-v3` + `float16` | NaN output — `"!!!!"`, language `pa` |
  | `distil-large-v3` + `int8` | loads (1152 MiB) but hallucinates |
  | `distil-large-v3` + `float32` | CUDA OOM at 3612/4096 MiB |
  | **`distil-medium.en` + `float32`** | **correct, 2110/4096 MiB** |

  The rule that fell out: on this card prefer a **smaller model at full precision** over a
  cheaper precision on a big model. `float16` is effectively unusable here.

  **GPU consumers:** `whisperx` only. There is no time-slicing configured, so
  `nvidia.com/gpu: 1` admits exactly one pod — reviving `parakeet` would contend with the
  Obsidian transcription path.

### Storage Architecture

- **Primary**: UGREEN NAS with 12TB (4x3TB RAID5)
- **Provisioning**: NFS CSI driver with dynamic PV creation
- **Classes**: Differentiated storage classes for apps, databases, backups
- **Backup**: Velero with scheduled snapshots

### Network Topology

- **Ingress**: Traefik with automatic TLS via cert-manager
- **External**: Cloudflare Tunnels (zero port forwarding)
- **Internal**: Kubernetes DNS, service discovery
- **Hardware**: UniFi Dream Machine, managed switches

---

## Operational Excellence

### Automated Dependency Management

Renovate bot maintains all container images and Helm charts:

```json
{
  "extends": ["config:recommended"],
  "kubernetes": { "fileMatch": ["\\.yaml$"] },
  "flux": { "fileMatch": ["apps/.+\\.ya?ml$"] },
  "automerge": false,
  "prConcurrentLimit": 10
}
```

### Deployment Patterns

All applications follow standardized patterns:

```
apps/base/<app-name>/
├── namespace.yaml           # Isolated namespace
├── deployment.yaml          # Workload definition
├── service.yaml             # Internal service
├── ingress.yaml             # External access (Traefik + TLS)
├── secret-store.yaml        # AWS Secrets Manager access
├── external-secret.yaml     # Secret synchronization
└── kustomization.yaml       # Resource aggregation
```

### Disaster Recovery

- **GitOps**: Complete cluster state in version control
- **Backups**: Velero snapshots + PostgreSQL continuous archiving
- **Recovery**: Bootstrap from Git + restore persistent data
- **RTO Target**: < 1 hour for full cluster restoration

---

## Design Principles

1. **GitOps First**: If it's not in Git, it doesn't exist
2. **Declarative Everything**: No imperative commands for persistent changes
3. **Defense in Depth**: Multiple security layers (network, identity, secrets)
4. **Observability Native**: Monitoring from day one, not an afterthought
5. **Automation Over Documentation**: Automate everything that happens twice
6. **Minimal Complexity**: Right-size solutions for actual requirements

---

## Getting Started

### Prerequisites

- Kubernetes cluster (K3s recommended for homelab)
- AWS account (for Secrets Manager)
- GitHub account (for FluxCD)
- Basic understanding of Kubernetes and GitOps

### Bootstrap

```bash
# Clone repository
git clone https://github.com/lyzetam/fako-cluster

# Bootstrap Flux
flux bootstrap github \
  --owner=lyzetam \
  --repository=fako-cluster \
  --branch=main \
  --path=clusters/staging

# Watch reconciliation
flux get all -A --watch
```

### Common Operations

```bash
# Force reconciliation
flux reconcile source git flux-system && flux reconcile kustomization apps

# Check cluster health
kubectl get nodes && kubectl get pods -A --field-selector=status.phase!=Running

# View Flux logs
flux logs --follow --kind=Kustomization --name=apps

# GPU status
kubectl exec -n gpu-operator -it $(kubectl get pods -n gpu-operator \
  -l app=nvidia-device-plugin-daemonset -o jsonpath='{.items[0].metadata.name}') -- nvidia-smi
```

---

## Related Projects

- **[MLX Distributed Inference](https://github.com/lyzetam/mlx-distributed-inference)**: Distributed LLM inference on Apple Silicon clusters

---

## About

This project represents hands-on experience with production infrastructure patterns. Every architectural decision was made deliberately, every problem solved through research and iteration.

The goal isn't just to run services—it's to deeply understand how modern cloud-native systems work: from container scheduling to secret management, from GitOps workflows to GPU orchestration.

---

*Built by Landry Zetam | [Blog](https://blog.landryzetam.net) | [GitHub](https://github.com/lyzetam)*

*Infrastructure automation assisted by Claude AI*
