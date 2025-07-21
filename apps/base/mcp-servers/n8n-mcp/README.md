# n8n MCP Server

This directory contains the Kubernetes deployment for the n8n MCP (Model Context Protocol) server, which provides n8n workflow automation capabilities through MCP.

## Overview

The n8n MCP server allows Claude Desktop to interact with n8n workflows and documentation through the MCP protocol. It provides 39 tools for n8n API interactions and workflow management.

## Current Status

✅ **Deployment**: Running successfully in Kubernetes  
✅ **Service**: Internal cluster access working  
✅ **Port-forward**: Local access via `kubectl port-forward`  
⚠️ **External Access**: DNS/Ingress issues preventing external access  

## Components

### Deployment
- **Image**: `ghcr.io/czlonkowski/n8n-mcp:latest`
- **Mode**: HTTP Fixed mode for persistent sessions
- **Port**: 3000
- **Resources**: 100m CPU / 128Mi RAM (requests), 500m CPU / 512Mi RAM (limits)

### Authentication
- Uses Bearer token authentication
- Token stored in SOPS-encrypted secret: `n8n-mcp-auth-secret`
- Current token: `Z9nkOFMIVbDC67ZgAsV4600r+0IhLBeOqxdPfV2tlUE=`

### Configuration
- **AUTH_TOKEN**: From `n8n-mcp-auth-secret` secret
- **N8N_API_KEY**: From `n8n-mcp-secret` (external secret from AWS)
- **N8N_API_URL**: From `n8n-mcp-secret` (external secret from AWS)
- **MCP_MODE**: `http` (fixed session mode)
- **PORT**: `3000`

## Access Methods

### 1. Port-forward (Currently Working)
```bash
# Start port-forward
kubectl port-forward -n mcp-servers service/n8n-mcp-server 8080:3000 &

# Test health endpoint
curl -H "Authorization: Bearer Z9nkOFMIVbDC67ZgAsV4600r+0IhLBeOqxdPfV2tlUE=" \
     http://localhost:8080/health

# Test MCP endpoint
curl -H "Authorization: Bearer Z9nkOFMIVbDC67ZgAsV4600r+0IhLBeOqxdPfV2tlUE=" \
     http://localhost:8080/mcp
```

### 2. External Access (Currently Not Working)
- **Domain**: `n8n-mcp.landryzetam.net`
- **Issue**: DNS resolves to `10.85.39.214` but load balancer is at `10.85.30.x`
- **Status**: 502 Bad Gateway due to TLS certificate issues

## Claude Desktop Integration

The server is configured in Claude Desktop via:

```json
{
  "mcpServers": {
    "n8n-remote": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "http://localhost:8080/mcp",
        "--header",
        "Authorization: Bearer Z9nkOFMIVbDC67ZgAsV4600r+0IhLBeOqxdPfV2tlUE="
      ]
    }
  }
}
```

## Troubleshooting

### Port-forward Script
Use the provided script to ensure port-forward is running:
```bash
./scripts/start-n8n-mcp-portforward.sh
```

### Common Issues

1. **502 Bad Gateway on external access**
   - TLS certificate not ready
   - DNS pointing to wrong IP
   - Use port-forward as workaround

2. **Connection refused**
   - Pod may be restarting
   - Check pod status: `kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server`

3. **Authentication errors**
   - Verify token in request headers
   - Check secret exists: `kubectl get secret -n mcp-servers n8n-mcp-auth-secret`

## Logs

View server logs:
```bash
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server -f
```

## Health Check

The server provides a health endpoint at `/health` that returns:
```json
{
  "status": "ok",
  "mode": "http-fixed",
  "version": "2.7.19",
  "uptime": 584,
  "memory": {"used": 13, "total": 14, "unit": "MB"},
  "timestamp": "2025-07-21T13:36:34.083Z"
}
```

## MCP Capabilities

The server provides 39 tools for n8n interactions including:
- Workflow management
- Node documentation
- API interactions
- Template search and management

Access the MCP endpoint info at `/mcp` (GET request) for full capabilities.
