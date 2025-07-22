# Filesystem MCP Server

This deployment runs the official Model Context Protocol (MCP) filesystem server in Kubernetes.

## Overview

The filesystem MCP server provides secure filesystem operations including:
- Read/write files
- Create/list/delete directories  
- Move files/directories
- Search files
- Get file metadata

## Transport Type

This server uses an HTTP-to-stdio bridge, making it accessible via HTTP while the underlying MCP server uses stdio transport.

## Usage

### Access the Server

The filesystem MCP server is now accessible via HTTP at: `https://filesystem-mcp.landryzetam.net`

The server automatically starts with access to three directories:
- `/data` - Main data storage
- `/logs` - Log storage  
- `/config` - Configuration storage

### MCP Client Configuration

For Claude Desktop, add this to your claude_desktop_config.json:

```json
{
  "mcpServers": {
    "filesystem-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://filesystem-mcp.landryzetam.net"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

## Volumes

The server has access to three persistent volumes:
- `/data` - Main data storage (filesystem-mcp-data PVC)
- `/logs` - Log storage (filesystem-mcp-logs PVC)
- `/config` - Configuration storage (filesystem-mcp-config PVC)

## Security

- Runs as non-root user (UID 1000)
- All filesystem operations are restricted to the allowed directories
- Capabilities dropped for enhanced security

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n mcp-servers -l app.kubernetes.io/name=filesystem-mcp-server
```

### View Logs
```bash
kubectl logs -n mcp-servers deployment/filesystem-mcp-server
```

### Test Server
```bash
# Test the health endpoint
kubectl exec -n mcp-servers deployment/filesystem-mcp-server -- \
  node -e "require('http').get('http://localhost:3000/health', res => { res.on('data', d => process.stdout.write(d)); });"

# Or check via the ingress URL
curl https://filesystem-mcp.landryzetam.net/health
```

## Notes

- The server requires at least one allowed directory to operate
- All arguments are interpreted as directory paths (no flags like --help)
- The container runs an HTTP bridge on port 3000 that forwards requests to the MCP server
- Health checks available at `/health` endpoint
