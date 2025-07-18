# MCP Tools Integration Guide for Kagent

This guide explains how to integrate Model Context Protocol (MCP) tools with your Kagent agents to extend their capabilities beyond the built-in Kubernetes tools.

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [MCP Server Deployment](#mcp-server-deployment)
4. [Tool Discovery](#tool-discovery)
5. [Creating Agents with MCP Tools](#creating-agents-with-mcp-tools)
6. [Examples](#examples)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Overview

MCP (Model Context Protocol) tools extend Kagent agents by providing access to external services and capabilities. Unlike built-in tools, MCP tools can:
- Access external APIs and services
- Perform complex operations outside the Kubernetes cluster
- Provide specialized functionality (web scraping, database access, etc.)
- Be dynamically discovered and updated

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Kagent Agent  │────▶│   MCP Server     │────▶│ External Service│
│                 │     │ (in mcp-servers  │     │   or Resource   │
│ Uses MCP tools  │     │    namespace)    │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│ Tool Discovery  │     │ Service with     │
│   Mechanism     │────▶│ kagent.dev/tool  │
│                 │     │   annotations    │
└─────────────────┘     └──────────────────┘
```

## MCP Server Deployment

MCP servers are deployed in a dedicated `mcp-servers` namespace for better organization and security isolation.

### 1. Deploy the MCP Servers

```bash
# Apply the MCP servers configuration
kubectl apply -k apps/staging/mcp-servers/
```

### 2. Verify Deployment

```bash
# Check the namespace
kubectl get namespace mcp-servers

# View all MCP server resources
kubectl get all -n mcp-servers

# Check service annotations for tool discovery
kubectl get svc -n mcp-servers -o custom-columns=NAME:.metadata.name,TYPE:.metadata.annotations.kagent\\.dev/tool\\.type,DESCRIPTION:.metadata.annotations.kagent\\.dev/tool\\.description
```

## Tool Discovery

Kagent supports automatic tool discovery through service annotations. This eliminates the need for manual ToolServer configuration.

### Service Annotations

MCP servers must have these annotations on their services:

```yaml
metadata:
  annotations:
    kagent.dev/tool.type: "mcp"  # Required: Identifies as MCP server
    kagent.dev/tool.description: "Description of tools"  # Optional but recommended
    kagent.dev/tool.transport: "streamable-http"  # Optional: Transport mechanism
```

### Discovery Methods

1. **Automatic Discovery**: Agents discover all tools in a namespace
2. **Service Reference**: Agents reference specific MCP services
3. **Selective Discovery**: Use label selectors to filter MCP servers

## Creating Agents with MCP Tools

### Method 1: Direct Service Reference

Reference a specific MCP server by service name:

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: my-agent
  namespace: kagent
spec:
  modelConfig: ollama-qwen3-30b-a3b
  tools:
  - type: McpServer
    mcpServer:
      service:
        name: kubernetes-mcp-server
        namespace: mcp-servers
      # Tools are auto-discovered from the service
```

### Method 2: Auto-Discovery with Labels

Discover all MCP servers matching specific labels:

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: auto-discover-agent
  namespace: kagent
spec:
  modelConfig: ollama-deepseek-coder
  tools:
  - type: AutoDiscovered
    autoDiscovered:
      namespace: mcp-servers
      selector:
        matchLabels:
          app.kubernetes.io/component: mcp-server
```

### Method 3: Specific Tool Selection

Reference specific tools from an MCP server:

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: selective-tools-agent
  namespace: kagent
spec:
  modelConfig: ollama-llama32
  tools:
  - type: McpServer
    mcpServer:
      service:
        name: kubernetes-mcp-server
        namespace: mcp-servers
      toolNames:
      - list_resources
      - get_pod_logs
      # Only these specific tools will be available
```

## Deployed Agents

Two production-ready agents are deployed with Kagent that demonstrate MCP tool integration:

### 1. Kubernetes Operator Agent (`k8s-operator`)

A comprehensive Kubernetes management agent that combines MCP tools with built-in Kagent tools:

- **Model**: Qwen3-30B-A3B (MoE architecture for efficiency)
- **Capabilities**:
  - Full cluster resource management
  - Pod logs and exec access
  - Manifest generation and validation
  - Resource creation and updates
- **Tools**: Auto-discovers all MCP servers + built-in Kagent tools

Access this agent in the Kagent dashboard as `k8s-operator`.

### 2. Web Analyzer Agent (`web-analyzer`)

A specialized agent for web content analysis:

- **Model**: DeepSeek Coder (optimized for structured data extraction)
- **Capabilities**:
  - Fetch and analyze web content
  - Extract key information
  - Summarize web pages
  - Structured data presentation
- **Tools**: MCP website fetcher with the `fetch` tool

Access this agent in the Kagent dashboard as `web-analyzer`.

## Creating Custom Agents

Follow these patterns to create your own agents with MCP tools:

### Pattern 1: Auto-Discovery

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: my-custom-agent
  namespace: kagent
spec:
  modelConfig: ollama-qwen3-30b-a3b
  tools:
  - type: AutoDiscovered
    autoDiscovered:
      namespace: mcp-servers
      selector:
        matchLabels:
          app.kubernetes.io/component: mcp-server
```

### Pattern 2: Specific MCP Server

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: my-focused-agent
  namespace: kagent
spec:
  modelConfig: ollama-deepseek-coder
  tools:
  - type: McpServer
    mcpServer:
      service:
        name: kubernetes-mcp-server
        namespace: mcp-servers
```

### Pattern 3: Mixed Tools

```yaml
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: my-hybrid-agent
  namespace: kagent
spec:
  modelConfig: ollama-mistral
  tools:
  # MCP tools
  - type: McpServer
    mcpServer:
      service:
        name: mcp-website-fetcher
        namespace: mcp-servers
  # Built-in tools
  - type: Builtin
    builtin:
      name: kagent.tools.k8s.GetResources
```

## Best Practices

### 1. Security
- Run MCP servers with least privilege
- Use RBAC to limit permissions
- Isolate MCP servers in dedicated namespace
- Review third-party MCP server code before deployment

### 2. Resource Management
- Set appropriate resource limits
- Use horizontal pod autoscaling for high-traffic MCP servers
- Monitor resource usage

### 3. High Availability
- Deploy multiple replicas of critical MCP servers
- Use pod anti-affinity rules
- Configure proper health checks

### 4. Tool Selection
- Use auto-discovery for flexibility
- Specify exact tools when you need control
- Combine MCP and built-in tools for best results

### 5. Model Selection
- Use Qwen3-30B-A3B for complex operations (MoE efficiency)
- Use DeepSeek for code-heavy tasks
- Use smaller models for simple operations

## Troubleshooting

### MCP Server Not Discovered

1. Check service annotations:
```bash
kubectl get svc -n mcp-servers <service-name> -o yaml | grep -A 5 annotations
```

2. Verify Kagent has permissions:
```bash
kubectl auth can-i list services -n mcp-servers --as=system:serviceaccount:kagent:kagent
```

### Tools Not Working

1. Check MCP server logs:
```bash
kubectl logs -n mcp-servers deployment/<mcp-server-name>
```

2. Test MCP server health:
```bash
kubectl exec -n mcp-servers deployment/<mcp-server-name> -- curl -s localhost:<port>/health
```

3. Verify network connectivity:
```bash
kubectl exec -n kagent deployment/kagent -- curl -s http://<service-name>.mcp-servers.svc.cluster.local
```

### Agent Can't Access Tools

1. Check agent configuration:
```bash
kubectl get agent <agent-name> -n kagent -o yaml
```

2. Verify tool discovery:
```bash
kubectl logs -n kagent deployment/kagent | grep "tool discovery"
```

## Adding Custom MCP Servers

To add your own MCP server:

1. Create deployment and service manifests
2. Add required annotations to the service
3. Deploy to mcp-servers namespace
4. Update agents to use the new tools

Example structure:
```
apps/base/mcp-servers/
└── my-custom-mcp/
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

## References

- [Kagent Documentation](https://kagent.dev)
- [Model Context Protocol Specification](https://modelcontextprotocol.io)
- [Example MCP Servers](https://github.com/modelcontextprotocol/servers)
- [Kubernetes MCP Server](https://github.com/manusa/kubernetes-mcp-server)
