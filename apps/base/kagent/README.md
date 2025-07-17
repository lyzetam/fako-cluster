# Kagent Configuration

This directory contains the configuration for Kagent, including model configurations and secrets management.

## GPUStack Integration

The GPUStack OpenAI-compatible endpoint is configured through the following resources:

### 1. AWS Secrets Manager Integration
- **Secret Store**: `aws-secret-store.yaml` - Configures access to AWS Secrets Manager
- **API Key Secret**: `external-secret-gpustack.yaml` - Fetches the OpenAI API key from AWS secret `gpustack/api-key-kagent` and creates the `kagent-openai` secret
- **Endpoints Secret**: `external-secret-endpoints.yaml` - Fetches the GPUStack base URL from AWS secret `ollama-webui/endpoints`

### 2. Model Configuration
- **ModelConfig**: `modelconfig-gpustack.yaml` - Configures the deepseek-r1 model with:
  - Model name: `deepseek-r1`
  - Provider: OpenAI (GPUStack exposes an OpenAI-compatible endpoint)
  - API Key from secret: `kagent-openai`
  - Base URL: Placeholder URL that needs to be updated with actual GPUStack endpoint

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
- `external-secret-gpustack.yaml` - External secret for GPUStack API key
- `external-secret-endpoints.yaml` - External secret for GPUStack base URL
- `modelconfig-gpustack.yaml` - Model configuration for deepseek-r1
- `repository-crds.yaml` - Helm repository for CRDs
- `repository.yaml` - Helm repository for Kagent
- `release-crds.yaml` - Helm release for CRDs
- `release.yaml` - Helm release for Kagent
- `kustomization.yaml` - Kustomize configuration
