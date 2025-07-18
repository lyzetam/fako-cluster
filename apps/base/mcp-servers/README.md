# MCP Servers for Kagent

This directory contains Model Context Protocol (MCP) servers that extend Kagent's capabilities through tool discovery.

## Overview

MCP servers are deployed in a dedicated `mcp-servers` namespace and are automatically discovered by Kagent through service annotations. This enables dynamic tool discovery without manual ToolServer configuration.

## Architecture

### Tool Discovery
Services are annotated with:
- `kagent.dev/tool.type: "mcp"` - Identifies the service as an MCP server
- `kagent.dev/tool.description` - Describes the tools provided
- `kagent.dev/tool.transport` - Specifies the transport mechanism (sse or streamable-http)

### Deployed MCP Servers

#### 1. Kubernetes MCP Server
- **Image**: `ghcr.io/manusa/kubernetes-mcp-server:latest`
- **Transport**: Streamable HTTP
- **Capabilities**:
  - List and get Kubernetes resources
  - View pod logs and execute commands
  - Generate Kubernetes manifests
  - Manage deployments, services, and other resources
- **RBAC**: Comprehensive permissions for cluster operations

#### 2. Website Fetcher MCP Server
- **Image**: `ghcr.io/peterj/mcp-website-fetcher:sha-d2db5b3`
- **Transport**: SSE (Server-Sent Events)
- **Capabilities**:
  - Fetch web content from URLs
  - Process and return structured data
- **Use Case**: Web scraping and content analysis

## Deployment

### Prerequisites
- Kubernetes cluster with Kagent installed
- kubectl configured to access the cluster

### Deploy MCP Servers
```bash
# From the cluster root directory
kubectl apply -k apps/staging/mcp-servers/
```

### Verify Deployment
```bash
# Check namespace and resources
kubectl get namespace mcp-servers
kubectl get all -n mcp-servers

# Check service annotations
kubectl get svc -n mcp-servers -o yaml | grep -A 3 "annotations:"
```

## Using MCP Tools in Agents

With tool discovery enabled, you can reference MCP tools in two ways:

### 1. Automatic Discovery (Recommended)
Agents can discover and use tools automatically:

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
Reference specific discovered tools:

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

## Adding New MCP Servers

1. Create a new directory under `apps/base/mcp-servers/`
2. Add deployment and service manifests
3. Ensure the service includes tool discovery annotations:
   ```yaml
   annotations:
     kagent.dev/tool.type: "mcp"
     kagent.dev/tool.description: "Your tool description"
     kagent.dev/tool.transport: "streamable-http" # or "sse"
   ```
4. Update the main kustomization.yaml to include your server
5. Deploy and verify tool discovery

## Security Considerations

- MCP servers run with least privilege principles
- Kubernetes MCP server has specific RBAC permissions
- All containers run as non-root users
- Resource limits prevent resource exhaustion
- Pod anti-affinity ensures high availability

## Troubleshooting

### Check MCP Server Logs
```bash
kubectl logs -n mcp-servers deployment/kubernetes-mcp-server
kubectl logs -n mcp-servers deployment/mcp-website-fetcher
```

### Verify Tool Discovery
```bash
# Check if Kagent can see the MCP services
kubectl get svc -n mcp-servers -l kagent.dev/tool.type=mcp
```

### Test MCP Server Health
```bash
# Kubernetes MCP server
kubectl exec -n mcp-servers deployment/kubernetes-mcp-server -- curl -s localhost:8080/health

# Website fetcher
kubectl exec -n mcp-servers deployment/mcp-website-fetcher -- curl -s localhost:8000/sse
```

## References

- [Kagent Documentation](https://kagent.dev)
- [Model Context Protocol](https://modelcontextprotocol.io)
- [manusa/kubernetes-mcp-server](https://github.com/manusa/kubernetes-mcp-server)
