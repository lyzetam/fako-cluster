# The Fako Cluster: A Systems Engineer's Journey into Modern Infrastructure

*How I built a production-grade Kubernetes homelab that bridges the gap between learning and real-world engineering*

## The Story Behind This Project

As a mechanical engineer turned systems engineer, I've always been fascinated by how things work under the hood. Just as I used to tear down engines to understand every component, I wanted to deconstruct modern cloud infrastructure and rebuild it from scratch. The Fako Cluster is that journey – a homelab that doesn't just run applications, but demonstrates how enterprise-grade systems are designed, secured, and operated.

This isn't your typical homelab with hardcoded configurations and manual deployments. It's a fully automated, GitOps-driven platform that showcases modern DevOps practices while running real workloads that improve my daily life.

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

## The Technical Architecture

### Infrastructure That Scales Down

One of the unique challenges was making enterprise patterns work on consumer hardware. Here's how I approached it:

```
7 Nodes, 1 Vision:
├── yeezyai (GPU Node)     → 24 cores, 32GB RAM, 2x NVIDIA GPUs
├── zz-macbookpro (Master) → 12 cores, 16GB RAM (my daily driver!)
└── 5 Worker Nodes         → Various specs, distributed across the house
```

### The GitOps Revolution

Traditional homelab: SSH in, run commands, hope it works.
My approach: 

```yaml
Git Push → Flux Detects → Kustomize Builds → Kubernetes Applies → Monitoring Alerts
```

Every change is tracked, reviewed, and automatically deployed. It's not just automation – it's a complete audit trail of how the infrastructure evolved.

### Dynamic Storage Without the Pain

Here's a problem every homelab faces: hardcoded NFS server IPs. When your NAS changes IPs, you're updating dozens of files. My solution? A Kubernetes job that:

1. Fetches NFS configuration from AWS Secrets Manager
2. Dynamically creates StorageClasses
3. Deletes itself when done

Zero hardcoded IPs. Pure GitOps.

## The Application Ecosystem

### 🤖 AI/ML Stack: Privacy-First Intelligence

Running LLMs locally isn't just about avoiding API costs – it's about data sovereignty:

- **Ollama**: GPU-accelerated inference server running models like Llama 3 and Mistral
- **Custom WebUI**: Beautiful interface that connects to both local and cloud models
- **Voice Pipeline**: Whisper → LLM → Piper for completely offline voice interactions

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

## The Monitoring Story

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

## Development Workflow: From Idea to Production

### The Two-Environment Strategy

```
main branch → Production (GPU-enabled, full resources)
dev branch  → Development (CPU-only, resource-constrained)
```

This isn't just about saving resources – it's about proving the applications work everywhere. If it runs in dev, it'll run in production.

### Continuous Everything

- **Continuous Deployment**: Git push triggers automatic rollout
- **Continuous Monitoring**: Every deployment tracked in Grafana
- **Continuous Updates**: Renovate bot keeps dependencies fresh
- **Continuous Learning**: Every failure documented and fixed in code

## Lessons Learned: The Hard-Won Wisdom

### What Worked Brilliantly

1. **External Secrets Operator**: Game-changer for secret management
2. **Flux's Kustomization Controller**: Perfect balance of flexibility and structure
3. **CloudNative-PG**: Production-grade PostgreSQL that "just works"
4. **GPU Operator**: Simplified what could have been driver hell

### What I'd Do Differently

1. Start with observability from day one (added it later, wished I hadn't)
2. Use Flux's multi-tenancy features earlier
3. Implement network policies from the start
4. Document as I go (hence this README!)

## The Human Side of Engineering

### Why This Matters

This cluster isn't just about running services – it's about understanding the entire stack. When I deploy an application, I know:
- How the container runtime works
- How service discovery happens
- How storage is provisioned
- How secrets are managed
- How traffic flows through the system

### The Learning Never Stops

Every week brings new challenges:
- Optimizing GPU memory for larger models
- Reducing cold starts for serverless-style workloads
- Improving backup strategies
- Enhancing security postures

## Getting Started: Your Own Journey

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

# Bootstrap Flux (this is where the magic begins)
flux bootstrap github \
  --owner=yourusername \
  --repository=fako-cluster \
  --branch=main \
  --path=clusters/staging

# Watch your cluster come alive
watch flux get all -A
```

## The Future: What's Next?

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

*Built with ❤️ and probably too much ☕ by Landry*

*Last updated: July 2025 | Running in production since: Forever in homelab years*
