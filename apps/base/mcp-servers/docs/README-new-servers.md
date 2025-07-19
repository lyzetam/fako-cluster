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


# MCP Servers in the mcp-servers Namespace

This document details the MCP (Model Context Protocol) servers deployed within the `mcp-servers` Kubernetes namespace.  These servers provide a range of capabilities for agents, enhancing their functionality with access to external tools and data.

## Overview

The `mcp-servers` namespace is dedicated to hosting MCP servers, providing better organization and security isolation.  These servers are designed to be discoverable by Kagent agents, enabling seamless integration with various tools.

## Deployed MCP Servers

The following MCP servers are currently deployed:

### 1. Kubernetes Operations (kubernetes-mcp-server)

*   **Service**: `kubernetes-mcp-server.mcp-servers.svc.cluster.local:3000`
*   **Purpose**: Kubernetes operations, including resource listing, pod log retrieval, and resource creation.
*   **Key Tools**: `list_resources`, `get_pod_logs`, `create_resource`

### 2. Web Content Fetching (fetch-mcp-server)

*   **Service**: `fetch-mcp-server.mcp-servers.svc.cluster.local:3000`
*   **Purpose**: Secure web scraping and HTML to markdown conversion.
*   **Transport**: HTTP
*   **Description**: Web content fetching server
*   **Capabilities**: Fetching web content.

### 3. Filesystem Operations (filesystem-mcp-server)

*   **Service**: `filesystem-mcp-server.mcp-servers.svc.cluster.local:3000`
*   **Purpose**: Secure filesystem operations for reading, writing, and managing files on persistent volumes.
*   **Transport**: stdio
*   **Security Features**:
    *   Path Validation
    *   File Size Limits (default: 10MB)
    *   Non-root Execution (UID 1000)
    *   Namespace Isolation
*   **Available Tools**:
    *   `read_file`: Reads file content.
    *   `write_file`: Writes content to a file.
    *   `list_directory`: Lists directory contents.
    *   `create_directory`: Creates a directory.
    *   `delete_file`: Deletes a file.

### 4. GitHub Operations (github-mcp-server)

*   **Service**: `github-mcp-server.mcp-servers.svc.cluster.local:3000`
*   **Purpose**: GitHub repository operations, issues, PRs, and file management.
*   **Transport**: HTTP
*   **Capabilities**:
    *   Repository management
    *   Issue creation and management
    *   Pull request operations
    *   File operations in repositories
    *   Release management
*   **Configuration**: Requires a GitHub Personal Access Token (base64 encoded) in `apps/base/mcp-servers/github-mcp/secret.yaml`.

### 5. Vector Database (ChromaDB) (vector-db-mcp-server)

*   **Service**: `vector-db-mcp-server.mcp-servers.svc.cluster.local:3000`
*   **Purpose**: Long-term memory and context storage with semantic search.
*   **Transport**: HTTP
*   **Storage**: 20Gi persistent volume.
*   **Capabilities**:
    *   Store and retrieve contextual memories
    *   Semantic search across stored content
    *   Context persistence across sessions
    *   Vector embeddings management

## Deployment

The MCP servers are deployed using Kubernetes manifests located in `apps/staging/mcp-servers/`. You can apply these manifests with:

```bash
kubectl apply -k apps/staging/mcp-servers/
```

### Verification

You can verify the deployment with the following commands:

```bash
kubectl get namespace mcp-servers
kubectl get all -n mcp-servers
kubectl get svc -n mcp-servers -o yaml | grep -A 3 "annotations:"
```

## Tool Discovery

Kagent supports automatic tool discovery through service annotations.  MCP servers *must* have these annotations on their services:

```yaml
metadata:
  annotations:
    mcp.dev/server.type: "mcp"  # Required: Identifies as MCP server
    mcp.dev/server.description: "Description of tools"  # Optional but recommended
    mcp.dev/server.transport: "transport-type"  # Optional: Transport mechanism
```

## Using MCP Tools in Agents

Agents can leverage these tools in two primary ways:

### 1. Automatic Discovery

Configure agents to automatically discover tools within the `mcp-servers` namespace:

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: k8s-operator
  namespace: kagent
spec:
  description: Kubernetes operator with auto-discovered tools
  modelConfig: default-model-config
  tools:
  - type: AutoDiscovered
    autoDiscovered:
      namespace: mcp-servers
      selector:
        matchLabels:
          app.kubernetes.io/component: mcp-server
```

### 2. Direct Tool Reference

Reference specific MCP services and their tools:

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: web-analyzer
  namespace: kagent
spec:
  description: Web content analyzer
  modelConfig: default-model-config
  tools:
  - type: McpServer
    mcpServer:
      service:
        name: mcp-website-fetcher
        namespace: mcp-servers
      toolNames:
      - fetch
```

# Security Policy for Fetch MCP Server

## Overview

The Fetch MCP Server provides web content fetching capabilities with built-in security measures to minimize risks associated with external web access.

## Security Measures

### Network Security
- **Network Policies**: Restricts egress traffic to HTTP (80), HTTPS (443), and DNS (53) only
- **No Private Network Access**: Application-level restrictions prevent access to private IP ranges
- **Ingress Control**: Only allows connections from authorized namespaces (mcp-servers, kagent)

### Container Security
- **Non-Root Execution**: Runs as user ID 1000 with dropped privileges
- **Read-Only Root Filesystem**: Prevents modification of system files (where possible)
- **No Privilege Escalation**: Container cannot escalate privileges
- **Capability Dropping**: All Linux capabilities are dropped
- **Security Context**: Enforced through Pod Security Policies

### Application Security
- **Robots.txt Compliance**: Respects website robots.txt files by default
- **Rate Limiting**: Built-in rate limiting (10 requests per 60 seconds by default)
- **Request Timeouts**: 30-second timeout prevents hanging requests
- **Content Length Limits**: Maximum 5000 characters by default
- **User Agent Identification**: Clear identification as MCP server

### Resource Security
- **Memory Limits**: 1Gi maximum memory usage
- **CPU Limits**: 500m maximum CPU usage
- **Storage Isolation**: Uses dedicated PVC for caching
- **Process Isolation**: No host network, PID, or IPC access

## Risk Assessment

### Potential Risks
1. **External Content Access**: Can fetch content from any public URL
2. **Data Exfiltration**: Could potentially be used to send data to external services
3. **Resource Consumption**: Malicious URLs could consume server resources
4. **Information Disclosure**: May reveal internal network information through error messages

### Mitigations
1. **Network Policies**: Restrict network access patterns
2. **Rate Limiting**: Prevent abuse through request throttling
3. **Resource Limits**: Prevent resource exhaustion
4. **Timeout Controls**: Prevent hanging connections
5. **Content Filtering**: Limit response sizes and types

## Configuration Security

### Environment Variables
- `FETCH_RESPECT_ROBOTS=true`: Enforces robots.txt compliance
- `FETCH_RATE_LIMIT=10`: Limits requests per window
- `FETCH_RATE_WINDOW=60000`: Rate limiting window (1 minute)
- `FETCH_TIMEOUT=30000`: Request timeout (30 seconds)
- `FETCH_MAX_LENGTH=5000`: Maximum content length

### Recommended Settings
- Keep robots.txt compliance enabled
- Use conservative rate limits
- Set appropriate timeouts
- Limit content length based on use case
- Monitor resource usage

## Monitoring and Alerting

### Recommended Monitoring
- Network traffic patterns
- Request rates and destinations
- Resource usage (CPU, memory)
- Error rates and types
- Response times

### Alert Conditions
- Unusual traffic patterns
- High error rates
- Resource limit approaches
- Repeated robots.txt violations
- Suspicious user agents or requests

## Incident Response

### Security Incident Types
1. **Abuse Detection**: Unusual request patterns or destinations
2. **Resource Exhaustion**: High CPU/memory usage
3. **Network Anomalies**: Unexpected traffic patterns
4. **Policy Violations**: Robots.txt or rate limit violations

### Response Actions
1. **Immediate**: Scale down or stop the service if needed
2. **Investigation**: Review logs and network traffic
3. **Mitigation**: Adjust rate limits or block problematic sources
4. **Recovery**: Restore service with enhanced monitoring

## Compliance

### Data Protection
- No persistent storage of fetched content (beyond caching)
- Respect for website terms of service
- Compliance with robots.txt standards
- User agent transparency

### Network Policies
- Egress restrictions to public internet only
- No access to cluster-internal services
- DNS resolution limited to necessary queries
- Monitoring of all network connections

## Updates and Maintenance

### Security Updates
- Regular updates of base container images
- Monitoring of security advisories for dependencies
- Automated vulnerability scanning
- Patch management procedures

### Configuration Reviews
- Regular review of security settings
- Rate limit effectiveness assessment
- Network policy validation
- Resource limit optimization

## Contact

For security concerns or incidents related to the Fetch MCP Server, please follow your organization's security incident response procedures.
