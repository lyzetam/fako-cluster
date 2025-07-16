# Kagent Installation Guide

Kagent is an AI assistant for Kubernetes operations that requires special installation steps.

## Prerequisites

1. OpenAI API Key (or compatible API like GPUStack)
2. Kubernetes cluster access
3. kubectl configured

## Installation Steps

### 1. Install Kagent CLI

```bash
# Download and install the kagent CLI
curl https://raw.githubusercontent.com/kagent-dev/kagent/refs/heads/main/scripts/get-kagent | bash
```

### 2. Set up API Key

For GPUStack integration (using the existing GPUStack server):

```bash
export OPENAI_API_KEY="your-gpustack-api-key"
export OPENAI_API_BASE="http://***NFS-IP-REMOVED***:80/v1"
```

### 3. Install Kagent to Cluster

```bash
kagent install
```

This will:
- Install the necessary CRDs
- Deploy the Kagent components
- Set up the required agents

### 4. Access Kagent Dashboard

```bash
kagent dashboard
```

This will open the Kagent UI at http://localhost:8082

### 5. Configure Ingress (Optional)

If you want to expose Kagent externally, you can apply the ingress configuration:

```bash
kubectl apply -f apps/dev/kagent/ingress.yaml
```

This will make Kagent available at: http://kagent-dev.landryzetam.net

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
