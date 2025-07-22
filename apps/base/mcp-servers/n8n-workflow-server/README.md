# N8N Workflow MCP Server

This MCP server provides tools to interact with N8N workflows from Claude Desktop.

## Features

The server provides the following tools:

- **list_workflows**: List all workflows in N8N (with optional filtering by active status)
- **execute_workflow**: Execute a specific N8N workflow with optional input data
- **get_workflow**: Get details of a specific workflow
- **get_executions**: Get execution history for a workflow

## Configuration

### 1. Deploy to Kubernetes

The server is deployed as part of the fako-cluster MCP servers:

```bash
kubectl apply -k apps/base/mcp-servers/n8n-workflow-server/
```

### 2. Set up N8N API Key

Create the N8N API key in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name n8n/api-key \
  --secret-string '{"value":"your-n8n-api-key-here"}'
```

You can get your N8N API key from the N8N UI:
1. Go to Settings → API
2. Create a new API key
3. Copy the key value

### 3. Configure Claude Desktop

Add the following to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "n8n-workflow-server": {
      "command": "kubectl",
      "args": [
        "exec",
        "-i",
        "-n", "mcp-servers",
        "deployment/n8n-workflow-server",
        "--",
        "python",
        "/app/server.py"
      ]
    }
  }
}
```

Alternatively, if you're using port-forwarding:

```json
{
  "mcpServers": {
    "n8n-workflow-server": {
      "command": "python",
      "args": ["-m", "mcp.client.stdio", "http://localhost:8080"]
    }
  }
}
```

## Usage Examples

Once configured, you can use the N8N tools in Claude:

1. **List all active workflows:**
   ```
   Use the list_workflows tool with active=true
   ```

2. **Execute a workflow:**
   ```
   Use the execute_workflow tool with workflow_id="your-workflow-id" and data={"key": "value"}
   ```

3. **Get workflow details:**
   ```
   Use the get_workflow tool with workflow_id="your-workflow-id"
   ```

4. **Check execution history:**
   ```
   Use the get_executions tool with workflow_id="your-workflow-id" and limit=10
   ```

## Architecture

This MCP server follows the GitOps pattern:
- Source code is stored in a ConfigMap
- No external dependencies or Docker registry required
- Secrets are managed through AWS Secrets Manager
- Deployment is fully declarative

## Troubleshooting

1. **Check pod status:**
   ```bash
   kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-workflow-server
   ```

2. **View logs:**
   ```bash
   kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-workflow-server
   ```

3. **Verify API key secret:**
   ```bash
   kubectl get secret -n mcp-servers n8n-api-credentials
   ```

4. **Test connectivity to N8N:**
   ```bash
   kubectl exec -n mcp-servers deployment/n8n-workflow-server -- \
     curl -H "X-N8N-API-KEY: $(kubectl get secret -n mcp-servers n8n-api-credentials -o jsonpath='{.data.api-key}' | base64 -d)" \
     http://n8n.n8n.svc.cluster.local:5678/api/v1/workflows
