# Filesystem MCP Server

This deployment runs the official Model Context Protocol (MCP) filesystem server in Kubernetes using the official Docker image.

## Overview

The filesystem MCP server provides secure filesystem operations including:
- Read/write files
- Create/list/delete directories  
- Move files/directories
- Search files
- Get file metadata

## Architecture

This deployment uses the **official MCP filesystem Docker image** (`mcp/filesystem`):

- Runs the authentic MCP filesystem server as a persistent process
- Has access to persistent volumes: `/data`, `/logs`, `/config`
- Proper stdio transport as designed by the MCP specification
- Security-hardened with non-root user and dropped capabilities

### Current Status:
- **Phase 1**: Running the official MCP server container ✅
- **Phase 2**: HTTP bridge for remote access ✅

## Usage

The server follows the official MCP filesystem Docker pattern with all directories mounted under `/projects`:

- `/projects/data` - Main data storage (filesystem-mcp-data PVC: 10GB)
- `/projects/logs` - Log storage (filesystem-mcp-logs PVC: 5GB) 
- `/projects/config` - Configuration storage (filesystem-mcp-config PVC: 2GB)
- `/projects/workspace` - **Shared workspace** for N8N workflows (mcp-shared-workspace PVC: 20GB)

**Note**: The shared workspace enables seamless integration with N8N workflows and other MCP servers.

## Volumes

The server has access to four persistent volumes mounted under `/projects`:

- `/projects/data` - Main data storage (10GB, NFS)
- `/projects/logs` - Log storage (5GB, NFS)
- `/projects/config` - Configuration storage (2GB, NFS)
- `/projects/workspace` - **Shared workspace for workflows** (20GB, NFS, ReadWriteMany)

## N8N Workflow Integration

The shared workspace (`/projects/workspace`) enables powerful workflow integrations:

**File Exchange Pattern:**
1. **fetch-mcp** downloads content → `/projects/workspace/downloads/`
2. **N8N workflow** processes files → `/projects/workspace/processing/`
3. **LLM analysis** reads/writes → `/projects/workspace/analysis/`
4. **filesystem-mcp** manages all file operations across the entire `/projects` tree

**Directory Structure:**
```
/projects/
├── data/           # Persistent app data
├── logs/           # Application logs  
├── config/         # Configuration files
└── workspace/      # SHARED: N8N workflows, downloads, processing
    ├── downloads/  # Files fetched by fetch-mcp
    ├── processing/ # Files being processed by N8N
    └── analysis/   # LLM analysis results
```

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
  ps aux | grep 'node.*index.js'
```

## Architecture Details

**Two-Deployment Architecture:**

**1. MCP Server Deployment** (`filesystem-mcp-server`):
- **Uses official MCP filesystem Docker image** (`mcp/filesystem`)
- **Runs persistent MCP server process** with access to `/projects/*` directories
- **Process monitoring** to keep container alive and healthy
- **No network exposure** - internal container only

**2. HTTP Bridge Deployment** (`filesystem-mcp-bridge`):
- **Separate Node.js container** that routes HTTP/WebSocket traffic
- **Connects to MCP server** via `kubectl exec` commands
- **Exposes HTTP endpoints** at `/health` and `/mcp`
- **WebSocket support** for real-time bidirectional communication
- **Ingress-accessible** at `https://filesystem-mcp.landryzetam.net`

## Claude Desktop Configuration

Your Claude Desktop is already configured correctly:

```json
{
  "mcpServers": {
    "filesystem-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://filesystem-mcp.landryzetam.net/mcp"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

The bridge deployment will handle routing traffic from Claude Desktop to the MCP server container.

## Benefits of Two-Deployment Architecture

✅ **Clean Separation**: MCP server stays as official container  
✅ **Easy Updates**: Update MCP server without touching bridge code  
✅ **Scalability**: Can run multiple bridge instances for load balancing  
✅ **Security**: MCP server has no network exposure  
✅ **Flexibility**: Bridge can add additional HTTP endpoints as needed  

## Notes

- The MCP server runs the official Docker image exactly as designed
- The bridge provides HTTP/WebSocket access for remote clients
- Both deployments share access to the same persistent volumes
- N8N workflows can mount the shared workspace PVC directly
