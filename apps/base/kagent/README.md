# Kagent Installation Guide

Kagent is an AI assistant for Kubernetes operations. This deployment uses Helm with Flux to manage the installation.

## Overview

This setup deploys Kagent using:
- Two Helm releases: one for CRDs and one for the main application
- External Secrets for GPUStack API credentials
- Ingress configuration for external access

## Architecture

1. **kagent-crds**: Installs the Custom Resource Definitions
2. **kagent**: Main application deployment (depends on CRDs)
3. **External Secrets**: Pulls GPUStack API key from AWS Secrets Manager
4. **Ingress**: Exposes Kagent at kagent-dev.landryzetam.net

## Configuration

### GPUStack Integration

The deployment is configured to use GPUStack as the LLM provider:
- API endpoint: `http://10.85.35.223:80/v1`
- API key: Retrieved from AWS Secrets Manager at `gpustack/api-key`

### Resource Limits

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Manual Installation (Alternative)

If you prefer to install Kagent manually using the CLI:

### 1. Install Kagent CLI

```bash
# Download and install the kagent CLI
curl https://raw.githubusercontent.com/kagent-dev/kagent/refs/heads/main/scripts/get-kagent | bash
```

### 2. Set up API Key

```bash
export OPENAI_API_KEY="your-gpustack-api-key"
export OPENAI_API_BASE="http://10.85.35.223:80/v1"
```

### 3. Install Kagent

```bash
kagent install
```

### 4. Access Dashboard

```bash
kagent dashboard
```

## Using Kagent

### CLI Usage

```bash
# List available agents
kagent >> get agents

# Start a chat session
kagent >> run chat

# Select an agent and ask questions about your cluster
```

### Available Agents

- **k8s-agent**: General Kubernetes operations
- **helm-agent**: Helm chart management
- **observability-agent**: Monitoring and metrics
- **istio-agent**: Service mesh operations

## Integration with GPUStack

The configuration files in this directory are set up to use GPUStack as the LLM provider. The External Secrets are configured to pull:
- API key from `gpustack/api-key`
- Base URL from `ollama-webui/endpoints`

## Troubleshooting

1. If you see CRD errors, ensure you've run `kagent install` first
2. Check that your API key is correctly set
3. Verify the GPUStack endpoint is accessible from your cluster

## Notes

- Kagent cannot be deployed via Helm/Flux due to CRD dependencies
- The CLI installation method is the recommended approach
- For production use, consider setting up proper authentication and TLS
