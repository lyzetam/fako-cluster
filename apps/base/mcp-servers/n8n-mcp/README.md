# n8n MCP Server

This directory contains the Kubernetes deployment for the n8n MCP (Model Context Protocol) server, which provides n8n workflow automation capabilities through MCP.

## Overview

The n8n MCP server allows Claude Desktop to interact with n8n workflows and documentation through the MCP protocol. It provides 39 tools for n8n API interactions and workflow management.

## Current Status

✅ **Deployment**: Running successfully in Kubernetes  
✅ **Service**: Internal cluster access working  
✅ **External Access**: HTTPS access via ingress working  
✅ **Claude Desktop Integration**: Successfully connected  

## Components

### Deployment
- **Image**: `ghcr.io/czlonkowski/n8n-mcp:latest`
- **Mode**: HTTP Fixed mode for persistent sessions
- **Port**: 3000
- **Resources**: 100m CPU / 128Mi RAM (requests), 500m CPU / 512Mi RAM (limits)

### Authentication
- Uses Bearer token authentication
- Token stored in SOPS-encrypted secret: `n8n-mcp-auth-secret`
- **Security Note**: Never expose authentication tokens in documentation or code

### Configuration
- **AUTH_TOKEN**: From `n8n-mcp-auth-secret` secret (SOPS encrypted)
- **N8N_API_KEY**: From `n8n-mcp-secret` (external secret from AWS)
- **N8N_API_URL**: From `n8n-mcp-secret` (external secret from AWS)
- **MCP_MODE**: `http` (fixed session mode)
- **PORT**: `3000`

## Access Methods

### 1. External Access (Recommended)
- **Domain**: `n8n-mcp.landryzetam.net`
- **Protocol**: HTTPS with self-signed certificate
- **Status**: ✅ Working

### 2. Port-forward (Development/Debugging)
```bash
# Start port-forward
kubectl port-forward -n mcp-servers service/n8n-mcp-server 8080:3000 &

# Test health endpoint (replace YOUR_TOKEN with actual token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8080/health

# Test MCP endpoint (replace YOUR_TOKEN with actual token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8080/mcp
```

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
        "https://n8n-mcp.landryzetam.net/mcp",
        "--header",
        "Authorization: Bearer YOUR_AUTH_TOKEN_HERE"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

**Important Security Notes:**
- Replace `YOUR_AUTH_TOKEN_HERE` with the actual token from the SOPS-encrypted secret
- The `NODE_TLS_REJECT_UNAUTHORIZED=0` environment variable is required for self-signed certificates
- Never commit actual tokens to version control

## Security Best Practices

1. **Token Management**:
   - All authentication tokens are stored in SOPS-encrypted secrets
   - Tokens are never exposed in plain text in documentation
   - Use `sops -d` to decrypt secrets when needed

2. **SSL/TLS**:
   - External access uses HTTPS with self-signed certificates
   - Claude Desktop configured to accept self-signed certificates via environment variable

3. **Access Control**:
   - Bearer token authentication required for all endpoints
   - Tokens rotated regularly (recommended)

## Troubleshooting

### Common Issues

1. **SSL Certificate Errors in Claude Desktop**
   - Ensure `NODE_TLS_REJECT_UNAUTHORIZED=0` is set in the environment
   - This allows connection to self-signed certificates

2. **Authentication errors**
   - Verify token is correctly retrieved from SOPS secret
   - Check secret exists: `kubectl get secret -n mcp-servers n8n-mcp-auth-secret`
   - Decrypt secret to verify token: `sops -d path/to/secret.yaml`

3. **Connection refused**
   - Pod may be restarting
   - Check pod status: `kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server`

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

## Token Retrieval

To get the authentication token for configuration:

```bash
# Decrypt the SOPS secret to get the token
sops -d apps/base/mcp-servers/n8n-mcp/auth-secret.yaml

# Or use kubectl to get the token (base64 encoded)
kubectl get secret -n mcp-servers n8n-mcp-auth-secret -o jsonpath='{.data.token}' | base64 -d
