# n8n MCP Server

A Model Context Protocol (MCP) server that provides comprehensive n8n workflow automation capabilities, enabling AI agents to create, manage, and execute workflows programmatically.

## Overview

The n8n MCP server acts as a bridge between AI agents and your n8n workflow automation platform, providing "workflows as code" functionality. It connects to your existing n8n instance via the REST API and offers full administrative capabilities for workflow management.

## Features

### Core Capabilities
- **Workflow Management**: Create, read, update, delete workflows programmatically
- **Execution Control**: Trigger workflows manually and monitor execution status
- **Credential Management**: Securely manage API keys, database connections, and other credentials
- **Template System**: Save and reuse workflow templates
- **Real-time Monitoring**: Track workflow executions and performance metrics

### Security Features
- **API Key Authentication**: Secure connection to n8n using API keys
- **Network Isolation**: NetworkPolicy restricts access to n8n service only
- **Non-root Execution**: Container runs with dropped privileges
- **Resource Limits**: CPU and memory constraints prevent resource exhaustion

## Available Tools

### Workflow Operations
- `create_workflow` - Create new workflows from JSON definitions
- `list_workflows` - List all workflows with filtering options
- `get_workflow` - Retrieve specific workflow details
- `update_workflow` - Modify existing workflows
- `delete_workflow` - Remove workflows
- `activate_workflow` - Enable/disable workflow execution

### Execution Management
- `execute_workflow` - Trigger manual workflow execution
- `get_execution` - Retrieve execution details by ID
- `list_executions` - List workflow executions with filtering

### Credential Management
- `create_credential` - Add new credentials for workflows
- `list_credentials` - List available credentials by type

## Configuration

### Environment Variables
- `N8N_API_KEY` - API key for n8n authentication (required)
- `N8N_URL` - n8n instance URL (defaults to internal cluster service)

### Secret Management
The server uses Kubernetes secrets to store sensitive configuration:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: n8n-mcp-secret
stringData:
  api-key: "your-n8n-api-key"
  n8n-url: "http://n8n.n8n.svc.cluster.local:5678"
```

## Usage Examples

### Creating a Simple Workflow
```json
{
  "name": "oura-sleep-score-email",
  "workflow": {
    "nodes": [
      {
        "id": "postgres-node",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 1,
        "position": [250, 300],
        "parameters": {
          "query": "SELECT sleep_score, date FROM oura_sleep WHERE date = CURRENT_DATE - 1",
          "credentials": {
            "postgres": {
              "id": "postgres-cred-id"
            }
          }
        }
      },
      {
        "id": "email-node",
        "type": "n8n-nodes-base.emailSend",
        "typeVersion": 1,
        "position": [450, 300],
        "parameters": {
          "toEmail": "user@example.com",
          "subject": "Yesterday's Sleep Score: {{$node['postgres-node'].json['sleep_score']}}",
          "text": "Your sleep score for {{$node['postgres-node'].json['date']}} was {{$node['postgres-node'].json['sleep_score']}}",
          "credentials": {
            "smtp": {
              "id": "smtp-cred-id"
            }
          }
        }
      }
    ],
    "connections": {
      "postgres-node": {
        "main": [
          [
            {
              "node": "email-node",
              "type": "main",
              "index": 0
            }
          ]
        ]
      }
    },
    "settings": {
      "timezone": "America/New_York"
    }
  },
  "active": true
}
```

### Scheduling Workflows
Workflows can be scheduled using n8n's built-in cron trigger:
```json
{
  "nodes": [
    {
      "id": "cron-trigger",
      "type": "n8n-nodes-base.cron",
      "typeVersion": 1,
      "position": [100, 300],
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 8 * * *"
            }
          ]
        }
      }
    }
  ]
}
```

## Deployment

### Prerequisites
- n8n instance running in the cluster
- n8n API key with administrative privileges
- Network connectivity between mcp-servers and n8n namespaces

### Installation
```bash
# Deploy the n8n MCP server
kubectl apply -k apps/base/mcp-servers/n8n-mcp/

# Verify deployment
kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# Check logs
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server
```

### Configuration Steps
1. **Generate n8n API Key**:
   - Access your n8n instance
   - Go to Settings > API Keys
   - Create a new API key with full permissions

2. **Update Secret**:
   ```bash
   kubectl patch secret n8n-mcp-secret -n mcp-servers --type='merge' -p='{"stringData":{"api-key":"your-actual-api-key"}}'
   ```

3. **Verify Connectivity**:
   ```bash
   kubectl exec -n mcp-servers deployment/n8n-mcp-server -- wget -qO- http://n8n.n8n.svc.cluster.local:5678/healthz
   ```

## Integration with AI Agents

The n8n MCP server integrates seamlessly with kagent and other AI systems:

### Example AI Workflow Creation
An AI agent can create workflows using natural language:
```
"Create a workflow that checks my Oura sleep score from PostgreSQL and emails me if it's below 70"
```

This translates to MCP tool calls:
1. `create_credential` - Set up PostgreSQL and SMTP credentials
2. `create_workflow` - Build the workflow with conditional logic
3. `activate_workflow` - Enable the workflow for execution

### Workflow Templates
Common workflow patterns can be saved as templates:
- **Data Processing**: ETL workflows for data transformation
- **Notifications**: Alert systems for various conditions
- **Integrations**: Connect different services and APIs
- **Monitoring**: Health checks and system monitoring

## Security Considerations

### Network Security
- NetworkPolicy restricts traffic to n8n service only
- No external internet access except for npm installs during init
- Ingress limited to kagent namespace

### Credential Security
- API keys stored in Kubernetes secrets
- Credentials encrypted at rest
- No credential data exposed in logs

### Container Security
- Non-root execution (UID 1000)
- Dropped capabilities
- Resource limits prevent DoS attacks
- Read-only root filesystem where possible

## Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check n8n service availability
   kubectl get svc -n n8n
   kubectl get pods -n n8n
   ```

2. **Authentication Errors**
   ```bash
   # Verify API key
   kubectl get secret n8n-mcp-secret -n mcp-servers -o yaml
   ```

3. **Network Policy Issues**
   ```bash
   # Check network policies
   kubectl get networkpolicies -n mcp-servers
   kubectl describe networkpolicy n8n-mcp-server-netpol -n mcp-servers
   ```

### Debug Commands
```bash
# Check pod status
kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# View logs
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# Test MCP server
kubectl exec -n mcp-servers deployment/n8n-mcp-server -- node /app/server.js

# Test n8n connectivity
kubectl exec -n mcp-servers deployment/n8n-mcp-server -- curl -H "X-N8N-API-KEY: $N8N_API_KEY" $N8N_URL/api/v1/workflows
```

## Performance Considerations

### Resource Usage
- **Memory**: 128Mi request, 512Mi limit
- **CPU**: 100m request, 500m limit
- **Storage**: Ephemeral storage for application files

### Scaling
- Single replica sufficient for most use cases
- Stateless design allows horizontal scaling if needed
- Consider n8n instance capacity when scaling

## Use Cases

### Automation Scenarios
1. **Data Pipeline Automation**: Create ETL workflows based on data patterns
2. **Alert Management**: Dynamic alert workflows based on system conditions
3. **Integration Workflows**: Connect services based on business logic
4. **Scheduled Tasks**: Create time-based automation workflows

### AI-Driven Workflow Management
- **Natural Language Workflow Creation**: Convert descriptions to workflows
- **Intelligent Scheduling**: Optimize workflow timing based on data patterns
- **Error Recovery**: Automatically create retry and fallback workflows
- **Performance Optimization**: Analyze and improve workflow efficiency

## Contributing

When extending the n8n MCP server:

1. **Follow n8n API Patterns**: Use official n8n API documentation
2. **Maintain Security**: Ensure all new features follow security best practices
3. **Add Tests**: Include unit tests for new functionality
4. **Update Documentation**: Keep this documentation current
5. **Consider Performance**: Monitor resource usage with new features

## Related Documentation

- [n8n API Documentation](https://docs.n8n.io/api/)
- [MCP Servers Overview](./README.md)
- [Kubernetes MCP Server](./kubernetes-mcp.md)
- [PostgreSQL MCP Server](./postgres-mcp.md)

## License

Part of the fako-cluster project. See project license for details.
