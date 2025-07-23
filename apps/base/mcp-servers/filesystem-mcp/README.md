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
- **Phase 2**: HTTP bridge for remote access (planned)

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

**Phase 1** - MCP Server Container:
1. **Uses official MCP filesystem Docker image** (`mcp/filesystem`)
2. **Runs persistent MCP server process** with access to `/data`, `/logs`, `/config`
3. **Process monitoring** to keep container alive and healthy
4. **Proper security context** with non-root user and dropped capabilities

## Notes

- The server requires at least one allowed directory to operate
- Currently runs the MCP server process in a monitoring loop to keep the container alive
- Phase 2 will add HTTP bridge for remote access
