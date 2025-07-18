# Kagent Configuration

This directory contains the configuration for Kagent, including model configurations and secrets management.

## Ollama Integration

Kagent is configured to use Ollama-hosted models for better compatibility with Mac-based clusters.

### 1. AWS Secrets Manager Integration
- **Secret Store**: `aws-secret-store.yaml` - Configures access to AWS Secrets Manager
- **API Key Secret**: `external-secret-gpustack.yaml` - Fetches the OpenAI API key from AWS secret `gpustack/api-key-kagent` and creates the `kagent-openai` secret (used for default OpenAI models)
- **Endpoints Secret**: `external-secret-endpoints.yaml` - Fetches endpoint configurations from AWS

### 2. Model Configuration
- **ModelConfig**: `modelconfig-ollama-deepseek.yaml` - Configures the deepseek-coder model with:
  - Model name: `deepseek-coder:6.7b-instruct`
  - Provider: Ollama
  - Host: `https://ollama.landryzetam.net`
  - Full modelInfo for function calling support

## Prerequisites

Before applying these resources, ensure:

1. AWS credentials are properly configured in the cluster
2. The following AWS Secrets Manager secrets exist:
   - `gpustack/api-key-kagent` with property `OPENAI_API_KEYS`
   - `ollama-webui/endpoints` with property `gpustack_base_url`

## Usage

Once the resources are applied to the cluster, the deepseek-r1 model will be available in the Kagent UI model dropdown when creating or updating agents.

## Files

- `namespace.yaml` - Creates the kagent namespace
- `aws-secret-store.yaml` - AWS Secrets Manager store configuration
- `external-secret-gpustack.yaml` - External secret for OpenAI API key
- `external-secret-endpoints.yaml` - External secret for endpoint configurations
- `modelconfig-ollama-deepseek.yaml` - Model configuration for deepseek-coder via Ollama
- `repository-crds.yaml` - Helm repository for CRDs
- `repository.yaml` - Helm repository for Kagent
- `release-crds.yaml` - Helm release for CRDs
- `release.yaml` - Helm release for Kagent
- `kustomization.yaml` - Kustomize configuration

## Model Configuration

### Ollama Integration (deepseek-coder)
- Uses Ollama-hosted deepseek-coder:6.7b-instruct model
- Full compatibility with Mac-based clusters
- Supports function calling through Ollama's implementation
- Endpoint: `https://ollama.landryzetam.net`
- Includes complete modelInfo for proper agent functionality
