# Gemini Code Assistant Context: Fako Cluster

This document provides context for the Gemini AI assistant to understand the `fako-cluster` repository.

## Project Overview

This repository contains the full Infrastructure as Code (IaC) for a production-grade Kubernetes homelab environment named "Fako Cluster". It is managed entirely through GitOps principles using FluxCD.

The cluster runs on a heterogeneous set of nodes (x86_64, ARM64, Apple Silicon) and leverages K3s, a lightweight Kubernetes distribution. It hosts over 40 microservices, including AI/ML workloads on NVIDIA GPUs, high-availability PostgreSQL databases, and a full observability stack.

**Key Technologies:**

*   **Orchestration:** K3s Kubernetes
*   **GitOps:** FluxCD
*   **Configuration:** Kustomize
*   **Cloud Integration:** AWS Secrets Manager for secret management.
*   **Security:** External Secrets Operator, SOPS, Keycloak for SSO, Cloudflare Tunnels.
*   **Databases:** CloudNative-PG for HA PostgreSQL clusters.
*   **AI/ML:** NVIDIA GPU Operator, Ollama for LLM serving, Whisper for speech-to-text.
*   **Monitoring:** Prometheus, Loki, and Grafana.
*   **Dependency Management:** Renovate bot.

## Repository Structure

The repository is organized to separate applications, infrastructure, monitoring, and cluster definitions:

```
fako-cluster/
├── apps/                           # Application deployments (40+ services)
│   ├── base/                       # Base Kustomize configurations for each app
│   └── staging/                    # Production overlays and patches
│
├── infrastructure/
│   ├── controllers/                # Platform operators (e.g., external-secrets, gpu-operator)
│   └── configs/                    # Global configurations (e.g., Certificates, StorageClasses)
│
├── monitoring/
│   ├── controllers/                # Prometheus, Loki, Grafana stack operators
│   └── configs/                    # Dashboards, alerting rules
│
└── clusters/staging/               # Flux bootstrap and entry-point configuration
```

## Development and Operational Workflow

### GitOps Workflow

The core principle is "GitOps First": the Git repository is the single source of truth. Manual `kubectl` changes are forbidden for persistent state.

1.  **Commit:** A change is made by pushing a commit to the `main` branch on GitHub.
2.  **Detect:** The Flux Source Controller detects the change (polling every minute).
3.  **Reconcile:** Flux Kustomize and Helm controllers apply the manifests to the cluster.
4.  **Verify:** Flux continuously checks for drift between the Git state and the cluster state.

### Bootstrapping a New Cluster

To bootstrap a new cluster from this repository:

```bash
# 1. Clone the repository
git clone https://github.com/lyzetam/fako-cluster

# 2. Set up Flux to point to the repository
flux bootstrap github \
  --owner=lyzetam \
  --repository=fako-cluster \
  --branch=main \
  --path=clusters/staging

# 3. Monitor the reconciliation process
flux get all -A --watch
```

### Adding a New Application

To add a new application, follow the established pattern:

1.  Create a new directory under `apps/base/<app-name>/`.
2.  Inside, create the necessary Kubernetes manifests:
    *   `namespace.yaml`
    *   `deployment.yaml`
    *   `service.yaml`
    *   `ingress.yaml` (if exposed)
    *   `external-secret.yaml` and `secret-store.yaml` for secrets.
    *   `kustomization.yaml` to bundle the resources.
3.  Add a reference to the new application's kustomization in `apps/staging/kustomization.yaml`.
4.  Commit and push the changes. Flux will automatically deploy the application.

### Secret Management

Secrets are **never** stored in Git. The workflow is:
1.  Secrets are stored securely in AWS Secrets Manager.
2.  The `ExternalSecret` custom resource is defined in the application's manifests.
3.  The External Secrets Operator, running in the cluster, reads the `ExternalSecret` definition.
4.  It fetches the secret value from AWS Secrets Manager.
5.  It creates a native Kubernetes `Secret` in the application's namespace.
6.  The application pod mounts the native Kubernetes `Secret`.

### Common Operations

```bash
# Force a full reconciliation of the cluster state
flux reconcile source git flux-system && flux reconcile kustomization apps

# Check for pods that are not in a 'Running' state
kubectl get pods -A --field-selector=status.phase!=Running

# View logs for a specific Flux Kustomization
flux logs --follow --kind=Kustomization --name=apps

# Check NVIDIA GPU status on a GPU-enabled node
kubectl exec -n gpu-operator -it $(kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset -o jsonpath='{.items[0].metadata.name}') -- nvidia-smi
```
