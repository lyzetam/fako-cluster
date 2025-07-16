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
- API endpoint: Retrieved from AWS Secrets Manager at `ollama-webui/endpoints`
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
export OPENAI_API_BASE="your-gpustack-base-url"
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

The configuration uses External Secrets to securely manage GPUStack credentials:
- **API Key**: Retrieved from AWS Secrets Manager at `gpustack/api-key`
- **Base URL**: Retrieved from AWS Secrets Manager at `ollama-webui/endpoints`

Both values are automatically injected into the Kagent deployment, ensuring no sensitive information is hardcoded.

## Troubleshooting

1. **CRD Errors**: The Helm deployment handles CRD installation automatically
2. **Secret Errors**: Ensure AWS credentials are properly configured for External Secrets
3. **API Connection**: Verify the GPUStack endpoint is accessible from your cluster
4. **Pod Issues**: Check `kubectl logs -n dev-kagent kagent-<pod-id>` for detailed errors

## Current Deployment Status

The Kagent deployment includes:
- **CRDs**: Automatically installed via `kagent-crds` HelmRelease
- **Main Application**: Deployed via `kagent` HelmRelease with dependency on CRDs
- **External Secrets**: Configured to pull credentials from AWS Secrets Manager
- **Ingress**: Available at kagent-dev.landryzetam.net (dev environment)

## Notes

- The deployment uses a two-step Helm installation process (CRDs first, then main app)
- All sensitive configuration is managed through External Secrets
- For production use, ensure proper AWS credentials and TLS configuration
