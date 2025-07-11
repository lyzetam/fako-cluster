# The Fako Cluster: A Systems Engineer's Journey into Modern Infrastructure

*How I built a production-grade Kubernetes homelab that bridges the gap between learning and real-world engineering*

## The Story Behind This Project

As a mechanical engineer turned systems engineer, I've always been fascinated by how things work under the hood. Just as I used to design complex mechanical systems and rebuild engines with my dad during the summers, I wanted to deconstruct modern cloud infrastructure and rebuild it from scratch. Those summer days taught me that understanding comes from getting your hands dirty – whether it's adjusting valve clearances or configuring Kubernetes operators. The Fako Cluster is that same journey in the digital realm – a homelab that doesn't just run applications, but demonstrates how enterprise-grade systems are designed, secured, and operated.

This isn't your typical homelab with hardcoded configurations and manual deployments. It's a fully automated, GitOps-driven platform that showcases modern DevOps practices while running real workloads that improve my daily life.

## Table of Contents
- [What Makes This Special](#what-makes-this-special)
- [Complete Stack Overview](#complete-stack-overview)
- [Hardware Infrastructure](#hardware-infrastructure)
- [Repository Structure](#repository-structure)
- [The Application Ecosystem](#the-application-ecosystem)
- [Infrastructure Components](#infrastructure-components)
- [Security & Secret Management](#security--secret-management)
- [Monitoring & Observability](#monitoring--observability)
- [Development Workflow](#development-workflow)
- [Getting Started](#getting-started)
- [Lessons Learned](#lessons-learned)

## What Makes This Special?

### 🎯 Real Problems, Real Solutions

Every application in this cluster solves an actual need:
- **Health Tracking**: Automated collection and visualization of my Oura ring data
- **AI Assistant**: Local LLM inference for privacy-conscious AI interactions
- **Voice Pipeline**: Complete voice assistant system that respects my privacy
- **Knowledge Management**: Self-hosted bookmarks and audiobook server
- **Fitness Tracking**: Comprehensive workout and nutrition management

### 🔧 Engineering Philosophy in Action

This project embodies several core principles I believe in:

1. **Everything as Code**: No clicking through UIs. Every configuration, every deployment, every secret reference – it's all in Git. This isn't just about automation; it's about reproducibility and understanding.

2. **Security Without Compromise**: I store zero secrets in Git. Instead, I built a zero-trust architecture using AWS Secrets Manager and External Secrets Operator. Even the NFS server IPs are dynamically fetched from secrets!

3. **Observable by Design**: You can't improve what you can't measure. Full Prometheus/Loki/Grafana stack with custom dashboards for everything from GPU temperatures to backup success rates.

4. **Failure is a Feature**: The system assumes things will break. Automated backups, high availability deployments, and self-healing configurations ensure resilience.

## Complete Stack Overview

### 📊 Technology Stack by Category

| Category | Component | Purpose | Key Features |
|----------|-----------|---------|--------------|
| **Core Platform** | | | |
| | K3s | Lightweight Kubernetes | Production-grade, edge-optimized |
| | FluxCD | GitOps operator | Automated deployments, drift detection |
| | Traefik | Ingress controller | Built-in K3s, automatic TLS |
| | containerd | Container runtime | NVIDIA GPU support |
| **AI/ML Stack** | | | |
| | Ollama | LLM inference server | GPU-accelerated, multi-model support |
| | OpenWebUI | Chat interface | GPUStack backend, family access |
| | Whisper | Speech-to-text | GPU-accelerated, Wyoming protocol |
| | Piper | Text-to-speech | Neural TTS, multiple voices |
| | OpenWakeWord | Wake word detection | "Hey Jarvis", "Alexa" support |
| **Data & Analytics** | | | |
| | CloudNative-PG | PostgreSQL operator | 3-node HA, automated backups |
| | Oura Collector | Health data ETL | Smart backfill, API integration |
| | Oura Dashboard | Data visualization | Streamlit, real-time updates |
| | Wger | Fitness tracking | Workouts, nutrition, progress |
| **Identity & Security** | | | |
| | Keycloak | Identity provider | OIDC/SAML, multi-realm |
| | OAuth2 Proxy | SSO gateway | Protects all applications |
| | External Secrets | Secret management | AWS Secrets Manager integration |
| | Gitleaks | Secret scanning | Automated remediation |
| **Storage & Backup** | | | |
| | NFS CSI Driver | Dynamic storage | No hardcoded IPs |
| | Velero | Backup solution | Scheduled backups, disaster recovery |
| | CloudNative-PG | Database backups | Point-in-time recovery |
| **Monitoring** | | | |
| | Prometheus | Metrics collection | 30-day retention, HA setup |
| | Loki | Log aggregation | Distributed mode, 31-day retention |
| | Grafana | Visualization | Custom dashboards, alerting |
| | Alloy | Telemetry collector | OpenTelemetry support |
| **Web Applications** | | | |
| | Audiobookshelf | Media server | Audiobooks, podcasts, progress sync |
| | Linkding | Bookmark manager | Tags, search, API |
| | PGAdmin | Database UI | Multi-server, query tools |
| | Home Assistant | Smart home | Raspberry Pi, voice control |
| **Development Tools** | | | |
| | Renovate | Dependency updates | Automated PRs, grouped updates |
| | Node Labeling | Cluster management | Automatic node configuration |

## Hardware Infrastructure

### 🖥️ Detailed Node Specifications

One of the unique challenges was making enterprise patterns work on consumer hardware. Here's the complete infrastructure:

| Node | Role | CPU | Memory | Storage | GPU | Network | Cost |
|------|------|-----|---------|---------|-----|---------|------|
| **yeezyai** | GPU Worker | AMD Ryzen 9 3900X (24 cores @ 3.8GHz) | 32GB DDR4 | 957GB NVMe | NVIDIA RTX 5070 (12GB) + RTX 3050 | 1Gbps | ~$800 |
| **zz-macbookpro** | Control Plane | Apple M1 Pro (12 cores) | 16GB | 479GB SSD | - | WiFi 6 | Daily driver |
| **thinkpad01** | Worker | Intel i5-8250U (8 cores @ 1.6GHz) | 16GB DDR4 | 102GB SSD | - | 1Gbps | ~$80 |
| **pgmac01** | Worker | Intel Core i5 (4 cores @ 2.4GHz) | 8GB DDR3 | 102GB SSD | - | 1Gbps | ~$80 |
| **pgmac02** | Worker | Intel Core i5 (4 cores @ 2.4GHz) | 8GB DDR3 | 102GB SSD | - | 1Gbps | ~$80 |
| **pglenovo01** | Worker | Intel i5-6200U (4 cores @ 2.3GHz) | 8GB DDR4 | 100GB SSD | - | 1Gbps | ~$80 |
| **pglenovo02** | Worker | Intel i5-6200U (4 cores @ 2.3GHz) | 8GB DDR4 | 119GB SSD | - | 1Gbps | ~$80 |

**External Infrastructure:**
- **Synology NAS**: 12TB (4x3TB RAID5) for persistent storage
- **Raspberry Pi 4**: Home Assistant server (4GB RAM)
- **Network**: UniFi Dream Machine, managed switches

**Total Investment**: ~$1,200 (mostly refurbished hardware!)

The beauty? Each $80 node contributes to a distributed system that rivals cloud infrastructure costing thousands per month.

## Repository Structure

### 📁 GitOps Organization

```
fako-cluster/
├── apps/                    # Application deployments
│   ├── base/               # Base configurations (environment-agnostic)
│   │   ├── audiobookshelf/ # Each app has its own directory
│   │   ├── keycloak/       # with Kubernetes manifests
│   │   ├── ollama/         # ConfigMaps, Deployments, Services
│   │   └── ...             # Ingress, Storage, Secrets
│   ├── dev/                # Development overlays
│   │   └── kustomization.yaml # Patches for dev environment
│   └── staging/            # Production overlays
│       └── kustomization.yaml # Patches for production
│
├── clusters/               # Cluster bootstrapping
│   ├── dev/                # Dev cluster configuration
│   │   ├── apps.yaml       # Apps kustomization
│   │   ├── infrastructure.yaml # Infrastructure kustomization
│   │   └── monitoring.yaml # Monitoring kustomization
│   └── staging/            # Production cluster configuration
│       └── flux-system/    # Flux components
│
├── infrastructure/         # Platform components
│   ├── configs/            # Infrastructure configuration
│   │   ├── base/           # Shared configs
│   │   ├── dev/            # Dev-specific configs
│   │   └── staging/        # Prod-specific configs
│   └── controllers/        # Operators and controllers
│       ├── base/           # External Secrets, CSI drivers
│       ├── dev/            # Dev overrides
│       └── staging/        # Prod overrides
│
└── monitoring/             # Observability stack
    ├── configs/            # Dashboards, alerts
    └── controllers/        # Prometheus, Loki, Grafana
```

### GitOps Flow

```
GitHub Repository → Flux Source Controller → Kustomize Controller → Kubernetes API
                                         ↓
                                    Helm Controller
                                         ↓
                                 Deployed Resources
```

## The Application Ecosystem

### 🤖 AI/ML Stack: Privacy-First Intelligence

Running LLMs locally isn't just about avoiding API costs – it's about data sovereignty:

- **Ollama**: GPU-accelerated inference server running models like Llama 3 and Mistral on RTX 5070
- **OpenWebUI + GPUStack**: Beautiful interface powered by a distributed macOS cluster for family-wide AI access
- **MLX Distributed Inference**: Leveraging Apple Silicon for efficient model serving ([see the implementation →](https://github.com/lyzetam/mlx-distributed-inference))

**GPU Assignment Strategy**: The yeezyai node's dual GPUs are strategically allocated:
- **RTX 5070 (12GB GDDR7)**: Runs large language models with DLSS 4 and ray tracing capabilities
- **RTX 3050**: Dedicated to Whisper for speech-to-text processing
- Deployments use node affinity and GPU device selection for optimal resource utilization

### 🏠 The Alexa Replacement: Voice-First Smart Home

I built a complete voice assistant that respects privacy and runs entirely on-premises:

- **Home Assistant**: Running on Raspberry Pi, the brain of my smart home
- **Voice Preview Edition**: Captures voice input throughout the house
- **YeezyAI Processing**: The GPU node handles:
  - **Whisper**: Speech-to-text conversion
  - **LLM Integration**: Natural language understanding
  - **Piper**: Text-to-speech for responses
- **Result**: Full voice control of my home + AI conversations, zero cloud dependency

This isn't just about privacy – it's about ownership. My family's conversations stay in our home, processed by our hardware, under our control.

### 👨‍👩‍👧‍👦 Family AI: Governance at Home

The distributed AI infrastructure serves my entire family with proper governance:

- **GPUStack Backend**: macOS nodes clustered together for distributed inference
- **Multi-User Access**: Each family member has their own AI assistant access
- **Usage Monitoring**: Track and understand AI usage patterns
- **Content Filtering**: Age-appropriate responses for younger family members
- **Data Sovereignty**: All conversations, queries, and responses stay within our network

This demonstrates enterprise AI governance principles applied at home scale – proving that responsible AI doesn't require cloud providers.

### 🏥 Health & Fitness: Data-Driven Wellness

The Oura integration showcases full-stack development:
- **Collector Service**: Smart backfill logic that only fetches new data
- **PostgreSQL Storage**: Time-series optimized schema
- **Streamlit Dashboard**: Real-time visualization of sleep, activity, and readiness

[Check out the application code here →](https://github.com/lyzetam/fakocluster-apps)

### 🔐 Security: Enterprise Patterns at Home

- **Keycloak**: Full OIDC provider with HA deployment
- **OAuth2 Proxy**: Every app protected by SSO
- **Gitleaks**: Automated secret scanning with remediation
- **Network Policies**: Zero-trust networking between pods

## Infrastructure Components

### Dynamic Storage Without the Pain

Here's a problem every homelab faces: hardcoded NFS server IPs. When your NAS changes IPs, you're updating dozens of files. My solution? A Kubernetes job that:

1. Fetches NFS configuration from AWS Secrets Manager
2. Dynamically creates StorageClasses
3. Deletes itself when done

Zero hardcoded IPs. Pure GitOps.

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
- Automated backups to NFS
- Point-in-time recovery
- Connection pooling with PgBouncer
- Monitoring integration

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

## Monitoring & Observability

### Beyond Basic Metrics

Most homelabs have Grafana. Mine has:

- **Custom Dashboards**: GPU utilization, voice pipeline latency, backup status
- **Distributed Tracing**: OpenTelemetry integration for request flow analysis
- **Log Aggregation**: Every log searchable, correlated with metrics
- **Proactive Alerts**: Know about issues before they impact services

### The 3 AM Test

Can I diagnose and fix issues at 3 AM when I'm half asleep? The monitoring stack ensures:
- Clear error messages in logs
- Runbook links in alerts
- One-click rollback via Flux
- Automated recovery where possible

## Development Workflow

### The Two-Environment Strategy

```
main branch → Production (GPU-enabled, full resources)
dev branch  → Development (CPU-only, resource-constrained)
```

This isn't just about saving resources – it's about proving the applications work everywhere. If it runs in dev, it'll run in production.

### CPU-Only Development

Complete stack without GPU requirements:
- **Ollama**: CPU mode with small models (tinyllama, phi3)
- **Whisper**: INT8 optimized for CPU
- **Same Architecture**: Identical service structure as production

### Continuous Everything

- **Continuous Deployment**: Git push triggers automatic rollout
- **Continuous Monitoring**: Every deployment tracked in Grafana
- **Continuous Updates**: Renovate bot keeps dependencies fresh
- **Continuous Learning**: Every failure documented and fixed in code

## Getting Started

### Prerequisites (The Honest Version)

- **Hardware**: At least 3 nodes (VMs work too!)
- **Patience**: This isn't a weekend project
- **Curiosity**: You'll learn Kubernetes, GitOps, and about 20 other technologies
- **Coffee**: Lots of it

### Quick Start for the Brave

```bash
# Fork this repo and the apps repo
git clone https://github.com/yourusername/fako-cluster
git clone https://github.com/yourusername/fakocluster-apps

# Set up age encryption for secrets
age-keygen -o age.agekey

# Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# Bootstrap Flux (this is where the magic begins)
flux bootstrap github \
  --owner=yourusername \
  --repository=fako-cluster \
  --branch=main \
  --path=clusters/staging

# Watch your cluster come alive
watch flux get all -A
```

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

# Monitor backups
kubectl get backups -A
```

## Lessons Learned

### What Worked Brilliantly

1. **External Secrets Operator**: Game-changer for secret management
2. **Flux's Kustomization Controller**: Perfect balance of flexibility and structure
3. **CloudNative-PG**: Production-grade PostgreSQL that "just works"
4. **GPU Operator**: Simplified what could have been driver hell
5. **Dynamic NFS Configuration**: No more hardcoded IPs!

### What I'd Do Differently

1. Start with observability from day one (added it later, wished I hadn't)
2. Use Flux's multi-tenancy features earlier
3. Implement network policies from the start
4. Document as I go (hence this README!)
5. Set up automated testing for manifests

### The Human Side of Engineering

This cluster isn't just about running services – it's about understanding the entire stack. When I deploy an application, I know:
- How the container runtime works
- How service discovery happens
- How storage is provisioned
- How secrets are managed
- How traffic flows through the system

## The Future

### Immediate Roadmap

- **Service Mesh**: Exploring Linkerd for advanced traffic management
- **Backup to S3**: Extending backups beyond local NFS
- **Multi-Cluster**: Federation across multiple physical locations
- **Edge ML**: Deploying models to edge devices

### The Bigger Picture

This cluster is a living laboratory. It's where I test ideas before implementing them in production environments. It's where I learn new technologies in a safe space. Most importantly, it's where I can push boundaries without worrying about breaking someone else's infrastructure.

## Connect and Contribute

### Found a Bug? Have an Idea?

This project thrives on collaboration. Whether you're fixing a typo or proposing a new architecture pattern, contributions are welcome.

### The Code Behind the Magic

- **Infrastructure**: You're looking at it!
- **Applications**: [github.com/lyzetam/fakocluster-apps](https://github.com/lyzetam/fakocluster-apps)
- **MLX Distributed**: [github.com/lyzetam/mlx-distributed-inference](https://github.com/lyzetam/mlx-distributed-inference)

### Let's Talk Shop

I love discussing infrastructure, sharing war stories, and learning from others' experiences. If you're building something similar or have questions about any component, reach out!

---

## Final Thoughts

Building this cluster taught me more about modern infrastructure than any course or certification could. It forced me to understand not just the "how" but the "why" behind every architectural decision.

To future employers: This is how I approach systems engineering. I don't just deploy applications – I build platforms. I don't just solve today's problems – I architect for tomorrow's challenges. And I document everything because the best code is the code that others can understand and improve.

To fellow engineers: Your homelab doesn't have to be perfect. Start small, fail fast, and iterate. The journey is more valuable than the destination.

*"In the end, we are all apprentices in a craft where no one ever becomes a master."* – Ernest Hemingway

That's the beauty of systems engineering – there's always more to learn, always ways to improve, and always new problems to solve.

**Happy clustering!** 🚀

---

*Built with passion and probably too much ☕ by Landry*

*Documentation enhanced with the help of Claude AI – because even engineers need a good editor*

*Last updated: July 2025 | Running in production since: Forever in homelab years*
