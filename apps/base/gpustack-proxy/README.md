# GPUStack Proxy

This namespace provides a proxy service that exposes the GPUStack endpoint through a stable URL.

## Overview

The GPUStack proxy solves the problem of exposing a dynamic IP address in configuration files by:
1. Fetching the GPUStack endpoint IP from AWS Secrets Manager
2. Creating a Kubernetes Service/Endpoints that maps to this IP
3. Exposing the service through an Ingress with a stable domain name

## Components

- **Namespace**: `gpustack-proxy` - Isolated namespace for the proxy
- **AWS Secret Store**: Connects to AWS Secrets Manager to fetch the endpoint
- **External Secret**: Syncs the GPUStack base URL from AWS secret `ollama-webui/endpoints`
- **CronJob**: Runs every 30 minutes to sync the endpoint IP to Kubernetes Endpoints
- **Service**: ClusterIP service named `gpustack` that routes to the dynamic endpoint
- **Ingress**: Exposes the service at `https://gpustack.landryzetam.net`

## How it Works

1. The External Secret fetches the GPUStack URL from AWS Secrets Manager
2. The CronJob extracts the IP and port from the URL
3. It creates/updates Kubernetes Endpoints to point the Service to the actual IP
4. The Ingress routes external traffic to the Service
5. Applications can use `https://gpustack.landryzetam.net` without knowing the actual IP

## Usage

Other applications (like Kagent) can now use the stable URL:
```
https://gpustack.landryzetam.net/v1-openai
```

This URL will always route to the current GPUStack endpoint, even if the IP changes in AWS Secrets Manager.

## Manual Sync

To manually trigger an endpoint sync:
```bash
kubectl create job --from=cronjob/gpustack-endpoint-sync manual-sync-$(date +%s) -n gpustack-proxy
