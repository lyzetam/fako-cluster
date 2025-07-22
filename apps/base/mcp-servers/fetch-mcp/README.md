# Fetch MCP Server

This deployment provides the MCP Fetch server, which enables web content fetching capabilities for LLMs.

## Overview

The fetch server provides a `fetch` tool that:
- Fetches content from web URLs
- Converts HTML to markdown for easier LLM consumption
- Supports chunked reading via `start_index` parameter
- Respects robots.txt by default

## Security Considerations

⚠️ **CAUTION**: This server can access local/internal IP addresses and may represent a security risk. The deployment includes network policies to restrict access.

## Configuration

The server is configured with:
- Python 3.11 Alpine Linux base image
- HTTP transport on port 3000
- Runs as non-root user (UID/GID 1000)
- Resource limits (256Mi-1Gi memory, 100m-500m CPU)
- Security hardening (read-only root filesystem disabled for pip installs)

## Available Tools

### fetch
Fetches a URL from the internet and extracts its contents as markdown.

Parameters:
- `url` (string, required): URL to fetch
- `max_length` (integer, optional): Maximum number of characters to return (default: 5000)
- `start_index` (integer, optional): Start content from this character index (default: 0)
- `raw` (boolean, optional): Get raw content without markdown conversion (default: false)

## Usage

The server is exposed via Ingress at: `https://fetch-mcp.landryzetam.net`

For Claude Desktop, add this to your claude_desktop_config.json:
```json
{
  "mcpServers": {
    "fetch-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://fetch-mcp.landryzetam.net"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

## Implementation Details

- Uses Python 3.11 Alpine Linux base image
- Installs `mcp-server-fetch` Python package
- Implements an HTTP-to-stdio bridge since the fetch server only supports stdio transport
- The HTTP bridge listens on port 3000 and forwards requests to the MCP server
- Includes cache volume mounted at `/app/cache`
- Health checks via file-based readiness probe and HTTP health endpoint
- Network policy restricts egress to external IPs only

## Troubleshooting

Check pod logs:
```bash
kubectl logs -n mcp-servers deployment/fetch-mcp-server
```

Check pod status:
```bash
kubectl get pods -n mcp-servers -l app.kubernetes.io/name=fetch-mcp-server
