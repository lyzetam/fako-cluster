# New MCP Servers Deployment

This document describes the 5 new MCP servers that have been added to your cluster.

## Deployed MCP Servers

### 1. GitHub MCP Server
- **Service**: `github-mcp-server.mcp-servers.svc.cluster.local:3000`
- **Purpose**: GitHub repository operations, issues, PRs, and file management
- **Transport**: HTTP
- **Capabilities**:
  - Repository management
  - Issue creation and management
  - Pull request operations
  - File operations in repositories
  - Release management

**Configuration Required**:
- Update the GitHub token in `apps/base/mcp-servers/github-mcp/secret.yaml`
- Replace `cGxhY2Vob2xkZXJfdG9rZW4=` with your base64 encoded GitHub personal access token
- Get token from: https://github.com/settings/tokens

### 2. Vector Database MCP Server (ChromaDB)
- **Service**: `vector-db-mcp-server.mcp-servers.svc.cluster.local:3000`
- **Purpose**: Long-term memory and context storage with semantic search
- **Transport**: HTTP
- **Storage**: 20Gi persistent volume
- **Capabilities**:
  - Store and retrieve contextual memories
  - Semantic search across stored content
  - Context persistence across sessions
  - Vector embeddings management

**Features**:
- Includes ChromaDB backend for vector storage
- Persistent storage for data retention
- Ready for AI/ML workloads

### 3. Weather/External API MCP Server
- **Service**: `weather-mcp-server.mcp-servers.svc.cluster.local:3000`
- **Purpose**: Weather data and external API integrations
- **Transport**: HTTP
- **Capabilities**:
  - Weather data retrieval
  - Location-based services
  - External API proxy functionality
  - Support for multiple weather services

**Configuration Required**:
- Update the OpenWeather API key in `apps/base/mcp-servers/weather-mcp/secret.yaml`
- Replace `cGxhY2Vob2xkZXJfYXBpX2tleQ==` with your base64 encoded API key
- Get free API key from: https://openweathermap.org/api

### 4. File System MCP Server
- **Service**: `filesystem-mcp-server.mcp-servers.svc.cluster.local:3000`
- **Purpose**: File operations on mounted persistent volumes
- **Transport**: stdio
- **Storage**: 
  - 10Gi data volume (`/data`)
  - 5Gi logs volume (`/logs`)
  - 2Gi config volume (`/config`)
- **Capabilities**:
  - Read/write files on persistent storage
  - Directory operations
  - Log file analysis
  - Configuration file management

**Mounted Directories**:
- `/data` - General data storage
- `/logs` - Log file storage and analysis
- `/config` - Configuration file management

### 5. PostgreSQL MCP Server
- **Service**: `postgres-mcp-server.mcp-servers.svc.cluster.local:3000`
- **Purpose**: PostgreSQL database operations
- **Transport**: HTTP
- **Capabilities**:
  - SQL query execution
  - Schema inspection and analysis
  - Data analysis and reporting
  - Database administration tasks

**Configuration Required**:
- Update PostgreSQL connection details in `apps/base/mcp-servers/postgres-mcp/secret.yaml`
- Default configuration points to `postgres-cluster.postgres-cluster.svc.cluster.local`
- Update credentials to match your actual PostgreSQL setup

## Service Discovery Annotations

All services include MCP discovery annotations:
```yaml
annotations:
  mcp.dev/server.type: "mcp"
  mcp.dev/server.description: "Server description"
  mcp.dev/server.transport: "http|stdio|sse"
  mcp.dev/server.version: "1.0.0"
```

## Using MCP Servers

### With MCP-Compatible Clients
Connect to any server using its service endpoint:
- `github-mcp-server.mcp-servers.svc.cluster.local:3000`
- `vector-db-mcp-server.mcp-servers.svc.cluster.local:3000`
- `weather-mcp-server.mcp-servers.svc.cluster.local:3000`
- `filesystem-mcp-server.mcp-servers.svc.cluster.local:3000`
- `postgres-mcp-server.mcp-servers.svc.cluster.local:3000`

### With Kagent (if using Kubernetes agents)
Servers are automatically discoverable through service annotations.

### Port Forwarding for Local Development
```bash
# GitHub MCP Server
kubectl port-forward -n mcp-servers svc/github-mcp-server 3001:3000

# Vector DB MCP Server
kubectl port-forward -n mcp-servers svc/vector-db-mcp-server 3002:3000

# Weather MCP Server
kubectl port-forward -n mcp-servers svc/weather-mcp-server 3003:3000

# Filesystem MCP Server
kubectl port-forward -n mcp-servers svc/filesystem-mcp-server 3004:3000

# PostgreSQL MCP Server
kubectl port-forward -n mcp-servers svc/postgres-mcp-server 3005:3000
```

## Security Considerations

- All servers run as non-root users (UID 1000)
- Resource limits prevent resource exhaustion
- Secrets are used for sensitive configuration
- Network policies can be added for additional isolation

## Troubleshooting

### Check Server Status
```bash
kubectl get pods -n mcp-servers
kubectl get svc -n mcp-servers
```

### View Logs
```bash
kubectl logs -n mcp-servers deployment/github-mcp-server
kubectl logs -n mcp-servers deployment/vector-db-mcp-server
kubectl logs -n mcp-servers deployment/weather-mcp-server
kubectl logs -n mcp-servers deployment/filesystem-mcp-server
kubectl logs -n mcp-servers deployment/postgres-mcp-server
```

### Test Connectivity
```bash
kubectl exec -n mcp-servers deployment/github-mcp-server -- curl -s localhost:3000/health
```

## Next Steps

1. **Update Secrets**: Replace placeholder values in secret files with actual credentials
2. **Test Connections**: Verify each server is working with your credentials
3. **Configure Clients**: Connect your MCP clients to the deployed servers
4. **Monitor Usage**: Set up monitoring for the MCP servers
5. **Scale if Needed**: Adjust resource limits based on usage patterns

## Storage Usage

Total storage allocated:
- Vector DB: 20Gi
- Filesystem Data: 10Gi
- Filesystem Logs: 5Gi
- Filesystem Config: 2Gi
- **Total**: 37Gi additional storage

All using your existing `nfs-csi-v2` storage class.
