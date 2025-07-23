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

The server automatically starts with access to three directories mounted from PVCs:
- `/data` - Main data storage (filesystem-mcp-data PVC)
- `/logs` - Log storage (filesystem-mcp-logs PVC) 
- `/config` - Configuration storage (filesystem-mcp-config PVC)

**Note**: Currently running in Phase 1 - the MCP server container only. HTTP bridge for remote access will be added in Phase 2.

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

### Test HTTP Bridge
```bash
# Test the health endpoint
curl https://filesystem-mcp.landryzetam.net/health

# Test WebSocket connection (requires wscat)
wscat -c wss://filesystem-mcp.landryzetam.net
```

## Architecture Details

The bridge implementation:
1. **Starts ONE persistent MCP server** with access to `/data`, `/logs`, `/config`
2. **Provides HTTP endpoints** at `/health` and `/mcp` for health checks and HTTP requests
3. **Provides WebSocket endpoint** for bidirectional MCP communication
4. **Properly handles MCP JSON-RPC protocol** with message queuing and session management
5. **Maintains state** across multiple client interactions

## Notes

- The server requires at least one allowed directory to operate
- The HTTP bridge properly handles the MCP initialization sequence
- WebSocket communication is preferred for real-time bidirectional messaging
- HTTP POST to `/mcp` endpoint is available as fallback for simple requests
