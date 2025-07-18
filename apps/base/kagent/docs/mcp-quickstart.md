# MCP Tools Quick Start Guide

Get MCP tools running with Kagent in 5 minutes!

## Prerequisites
- Kubernetes cluster with Kagent installed
- kubectl access to the cluster

## Step 1: Deploy MCP Servers

```bash
# Deploy all MCP servers
kubectl apply -k apps/staging/mcp-servers/

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kagent -n mcp-servers --timeout=300s
```

## Step 2: Verify Deployment

```bash
# Check MCP servers are running
kubectl get pods -n mcp-servers

# Verify tool discovery annotations
kubectl get svc -n mcp-servers -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.kagent\.dev/tool\.type}{"\n"}{end}'
```

## Step 3: Create Your First MCP-Enabled Agent

```bash
# Create a simple agent with auto-discovered MCP tools
kubectl apply -f - <<EOF
apiVersion: kagent.dev/v1alpha1
kind: Agent
metadata:
  name: my-first-mcp-agent
  namespace: kagent
spec:
  description: My first agent with MCP tools
  modelConfig: ollama-deepseek-coder
  systemMessage: |-
    You are a helpful assistant with access to Kubernetes and web tools.
    Use your tools to help users with their requests.
  tools:
  - type: AutoDiscovered
    autoDiscovered:
      namespace: mcp-servers
      selector:
        matchLabels:
          app.kubernetes.io/component: mcp-server
EOF
```

## Step 4: Test Your Agent

1. Open the Kagent dashboard:
```bash
kubectl port-forward -n kagent svc/kagent 8001:80
```

2. Navigate to http://localhost:8001

3. Select "my-first-mcp-agent" from the agents list

4. Try these example prompts:
   - "What pods are running in the cluster?"
   - "Show me the contents of https://example.com"
   - "List all deployments in the default namespace"

## What's Next?

- Read the full [MCP Tools Integration Guide](./mcp-tools-integration-guide.md)
- Use the deployed agents: `k8s-operator` and `web-analyzer`
- Add your own MCP servers following the patterns in `apps/base/mcp-servers/`

## Quick Reference

### Available MCP Servers

| Server | Description | Key Tools |
|--------|-------------|-----------|
| kubernetes-mcp-server | Kubernetes operations | list_resources, get_pod_logs, create_resource |
| mcp-website-fetcher | Web content fetching | fetch |

### Agent Configuration Patterns

**Auto-discover all MCP tools:**
```yaml
tools:
- type: AutoDiscovered
  autoDiscovered:
    namespace: mcp-servers
```

**Use specific MCP server:**
```yaml
tools:
- type: McpServer
  mcpServer:
    service:
      name: kubernetes-mcp-server
      namespace: mcp-servers
```

**Mix MCP and built-in tools:**
```yaml
tools:
- type: McpServer
  mcpServer:
    service:
      name: mcp-website-fetcher
      namespace: mcp-servers
- type: Builtin
  builtin:
    name: kagent.tools.k8s.GetResources
```

## Troubleshooting

**MCP servers not starting?**
```bash
kubectl logs -n mcp-servers -l app.kubernetes.io/component=mcp-server
```

**Agent can't find tools?**
```bash
kubectl describe agent my-first-mcp-agent -n kagent
```

**Need help?**
- Check logs: `kubectl logs -n kagent deployment/kagent`
- Review service discovery: `kubectl get svc -n mcp-servers -o yaml`
