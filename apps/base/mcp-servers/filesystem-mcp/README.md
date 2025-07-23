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

This server uses the standard stdio transport protocol. It runs as a persistent service in Kubernetes but is designed to be used locally via direct execution.

## Usage

### Kubernetes Deployment

This Kubernetes deployment runs the filesystem MCP server with access to persistent volumes, but the server itself uses stdio transport.

The server automatically starts with access to three directories:
- `/data` - Main data storage (filesystem-mcp-data PVC)
- `/logs` - Log storage (filesystem-mcp-logs PVC)
- `/config` - Configuration storage (filesystem-mcp-config PVC)

### MCP Client Configuration

**Recommended Approach - Local Installation:**

For Claude Desktop, use the local NPX approach instead of the Kubernetes deployment:

```json
{
  "mcpServers": {
    "filesystem-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/username/Documents",
        "/Users/username/Desktop"
      ]
    }
  }
}
```

**Alternative - Docker Approach:**

```json
{
  "mcpServers": {
    "filesystem-mcp": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--mount", "type=bind,src=/Users/username/Desktop,dst=/projects/Desktop",
        "--mount", "type=bind,src=/path/to/other/dir,dst=/projects/other,ro",
        "mcp/filesystem",
        "/projects"
      ]
    }
  }
}
```

**Note:** The Kubernetes deployment is primarily for persistent storage management. MCP filesystem servers work best when run locally via stdio transport.

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

### Test Server Process
```bash
# Check if the MCP server process is running
kubectl exec -n mcp-servers deployment/filesystem-mcp-server -- \
  ps aux | grep mcp-server-filesystem
```

## Notes

- The server requires at least one allowed directory to operate
- All arguments are interpreted as directory paths (no flags like --help)  
- The server uses stdio transport and runs as a persistent process in the pod
- For production use, consider running the MCP server locally via NPX or Docker
