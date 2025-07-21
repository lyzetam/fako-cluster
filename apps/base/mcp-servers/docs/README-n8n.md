# n8n MCP Server

A Model Context Protocol server that provides comprehensive n8n workflow automation capabilities, enabling AI agents to create, manage, and execute workflows programmatically.

## Quick Start

### 1. Update AWS Secret with n8n API Key
The server uses External Secrets Operator to pull the API key from AWS Secrets Manager:

```bash
# Update the AWS secret with your actual n8n API key
aws secretsmanager update-secret \
  --secret-id "n8n/api-keys" \
  --secret-string '{"N8N_API_KEYS":"your-actual-n8n-api-key-here"}' \
  --region us-east-1
```

### 2. Deploy
```bash
# Deploy the n8n MCP server
kubectl apply -k apps/base/mcp-servers/n8n-mcp/

# Verify deployment
kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# Check logs
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server
```

### 3. Test Connectivity
```bash
# Test connection to n8n
kubectl exec -n mcp-servers deployment/n8n-mcp-server -- wget -qO- http://n8n.n8n.svc.cluster.local:5678/healthz
```

## Getting n8n API Key

1. Access your n8n instance at `https://n8n.landryzetam.net`
2. Go to **Settings** > **API Keys**
3. Click **Create API Key**
4. Give it a name (e.g., "MCP Server")
5. Copy the generated API key
6. Update the secret file with this key

## Available Tools

- `create_workflow` - Create new workflows
- `list_workflows` - List all workflows
- `get_workflow` - Get workflow details
- `update_workflow` - Update existing workflows
- `delete_workflow` - Delete workflows
- `execute_workflow` - Trigger workflow execution
- `get_execution` - Get execution details
- `list_executions` - List workflow executions
- `activate_workflow` - Enable/disable workflows
- `create_credential` - Create credentials
- `list_credentials` - List credentials

## Example Workflows

See `example-workflows.json` for ready-to-use workflow templates including:

- **Oura Sleep Score Email**: Daily email with sleep score from PostgreSQL
- **Simple Sleep Notification**: Basic sleep score notification

## Usage with AI Agents

Once deployed, AI agents can create workflows using natural language:

```
"Create a workflow that emails me my Oura sleep score every morning at 8 AM"
```

This will automatically:
1. Create the necessary credentials
2. Build the workflow with PostgreSQL query and email nodes
3. Set up the cron trigger
4. Activate the workflow

## Documentation

For detailed documentation, see [n8n-mcp.md](../docs/n8n-mcp.md).

## Troubleshooting

### Common Issues

1. **Pod not starting**: Check if n8n service is running
   ```bash
   kubectl get pods -n n8n
   ```

2. **Authentication errors**: Verify API key is correct
   ```bash
   kubectl get secret n8n-mcp-secret -n mcp-servers -o yaml
   ```

3. **Network issues**: Check network policies
   ```bash
   kubectl get networkpolicies -n mcp-servers
   ```

### Debug Commands

```bash
# Check pod status
kubectl describe pod -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# View detailed logs
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server -f

# Test n8n API directly
kubectl exec -n mcp-servers deployment/n8n-mcp-server -- curl -H "X-N8N-API-KEY: $N8N_API_KEY" $N8N_URL/api/v1/workflows
```

## Security

- API keys stored in Kubernetes secrets
- Network access restricted to n8n service only
- Non-root container execution
- Resource limits prevent resource exhaustion

## Next Steps

1. Deploy the server
2. Update your kagent configuration to include the n8n MCP server
3. Start creating workflows through AI agents!
