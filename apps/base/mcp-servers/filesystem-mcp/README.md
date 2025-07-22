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

This is a **stdio-based** MCP server, not HTTP. It must be accessed via `kubectl exec`.

## Usage

### Access the Server

To use the filesystem MCP server, execute it via kubectl:

```bash
kubectl exec -n mcp-servers deployment/filesystem-mcp-server -- \
  npx -y @modelcontextprotocol/server-filesystem /data /logs /config
```

### MCP Client Configuration

For Claude Desktop or other MCP clients, configure as follows:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "kubectl",
      "args": [
        "exec",
        "-n", "mcp-servers",
        "deployment/filesystem-mcp-server",
        "--",
        "npx", "-y", "@modelcontextprotocol/server-filesystem",
        "/data", "/logs", "/config"
      ]
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
# This will show an error about missing directories, confirming the server is working
kubectl exec -n mcp-servers deployment/filesystem-mcp-server -- \
  npx -y @modelcontextprotocol/server-filesystem
```

## Notes

- The server requires at least one allowed directory to operate
- All arguments are interpreted as directory paths (no flags like --help)
- The container runs a sleep loop to keep it available for kubectl exec
