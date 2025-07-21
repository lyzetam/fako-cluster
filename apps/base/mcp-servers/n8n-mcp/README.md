# n8n MCP Server

This directory contains the Kubernetes deployment for the official [n8n-MCP](https://github.com/czlonkowski/n8n-mcp) server, which provides AI assistants with comprehensive access to n8n node documentation, properties, and operations.

## Overview

The n8n-MCP server serves as a bridge between n8n's workflow automation platform and AI models, enabling them to understand and work with n8n nodes effectively. It provides structured access to:

- 📚 **528 n8n nodes** from both n8n-nodes-base and @n8n/n8n-nodes-langchain
- 🔧 **Node properties** - 99% coverage with detailed schemas
- ⚡ **Node operations** - 63.6% coverage of available actions
- 📄 **Documentation** - 90% coverage from official n8n docs (including AI nodes)
- 🤖 **AI tools** - 263 AI-capable nodes detected with full documentation

## Deployment

The server is deployed using the official Docker image `ghcr.io/czlonkowski/n8n-mcp:latest` which is:
- ⚡ **Ultra-optimized**: 82% smaller than typical n8n images
- 🔒 **Secure**: No n8n dependencies, just the runtime MCP server
- 📦 **Self-contained**: Pre-built database with all n8n node information

### Configuration

The deployment is configured with:
- **MCP_MODE**: `stdio` - For Model Context Protocol communication
- **LOG_LEVEL**: `error` - Minimal logging for production
- **DISABLE_CONSOLE_OUTPUT**: `true` - Clean stdio interface
- **N8N_API_KEY**: Retrieved from AWS Secrets Manager
- **N8N_API_URL**: Retrieved from AWS Secrets Manager

### Resources

- **Requests**: 128Mi memory, 100m CPU
- **Limits**: 512Mi memory, 500m CPU
- **Security**: Non-root user, read-only filesystem, dropped capabilities

## Available MCP Tools

Once connected, AI assistants can use these powerful tools:

### Core Tools
- **`tools_documentation`** - Get documentation for any MCP tool (START HERE!)
- **`list_nodes`** - List all n8n nodes with filtering options
- **`get_node_info`** - Get comprehensive information about a specific node
- **`get_node_essentials`** - Get only essential properties with examples (10-20 properties instead of 200+)
- **`search_nodes`** - Full-text search across all node documentation
- **`search_node_properties`** - Find specific properties within nodes
- **`list_ai_tools`** - List all AI-capable nodes (ANY node can be used as AI tool!)
- **`get_node_as_tool_info`** - Get guidance on using any node as an AI tool

### Advanced Tools
- **`get_node_for_task`** - Pre-configured node settings for common tasks
- **`list_tasks`** - Discover available task templates
- **`validate_node_operation`** - Validate node configurations (operation-aware, profiles support)
- **`validate_node_minimal`** - Quick validation for just required fields
- **`validate_workflow`** - Complete workflow validation including AI tool connections
- **`validate_workflow_connections`** - Check workflow structure and AI tool connections
- **`validate_workflow_expressions`** - Validate n8n expressions including $fromAI()
- **`get_property_dependencies`** - Analyze property visibility conditions
- **`get_node_documentation`** - Get parsed documentation from n8n-docs
- **`get_database_statistics`** - View database metrics and coverage

### n8n Management Tools
These powerful tools allow you to manage n8n workflows directly from AI assistants:

#### Workflow Management
- **`n8n_create_workflow`** - Create new workflows with nodes and connections
- **`n8n_get_workflow`** - Get complete workflow by ID
- **`n8n_get_workflow_details`** - Get workflow with execution statistics
- **`n8n_get_workflow_structure`** - Get simplified workflow structure
- **`n8n_get_workflow_minimal`** - Get minimal workflow info (ID, name, active status)
- **`n8n_update_full_workflow`** - Update entire workflow (complete replacement)
- **`n8n_update_partial_workflow`** - Update workflow using diff operations (80-90% token savings!)
- **`n8n_delete_workflow`** - Delete workflows permanently
- **`n8n_list_workflows`** - List workflows with filtering and pagination
- **`n8n_validate_workflow`** - Validate workflows already in n8n by ID

#### Execution Management
- **`n8n_trigger_webhook_workflow`** - Trigger workflows via webhook URL
- **`n8n_get_execution`** - Get execution details by ID
- **`n8n_list_executions`** - List executions with status filtering
- **`n8n_delete_execution`** - Delete execution records

#### System Tools
- **`n8n_health_check`** - Check n8n API connectivity and features
- **`n8n_diagnostic`** - Troubleshoot management tools visibility and configuration issues
- **`n8n_list_available_tools`** - List all available management tools

## Example: Creating Oura Sleep Score Workflow

Here's how to use the n8n-MCP server to create an automated Oura sleep score email workflow:

### 1. Discovery Phase
```
search_nodes({query: 'postgres'})
search_nodes({query: 'email'})
search_nodes({query: 'cron'})
```

### 2. Configuration Phase
```
get_node_essentials('n8n-nodes-base.cron')
get_node_essentials('n8n-nodes-base.postgres')
get_node_essentials('n8n-nodes-base.emailSend')
get_node_essentials('n8n-nodes-base.if')
```

### 3. Pre-Validation Phase
```
validate_node_minimal('n8n-nodes-base.cron', {
  rule: {
    interval: [{
      field: 'cronExpression',
      expression: '0 8 * * *'
    }]
  }
})

validate_node_minimal('n8n-nodes-base.postgres', {
  query: 'SELECT sleep_score, date FROM oura_sleep WHERE date = CURRENT_DATE - INTERVAL \'1 day\' LIMIT 1'
})
```

### 4. Building Phase
Create workflow with validated configurations:
- **Daily Trigger**: Cron node set to 8:00 AM Eastern Time
- **PostgreSQL Query**: Fetch yesterday's Oura sleep data
- **Condition Check**: Compare sleep score to threshold (70)
- **Email Nodes**: Send different messages based on sleep quality

### 5. Workflow Validation Phase
```
validate_workflow(workflowJson)
validate_workflow_connections(workflowJson)
validate_workflow_expressions(workflowJson)
```

### 6. Deployment Phase
```
n8n_create_workflow(validatedWorkflow)
n8n_validate_workflow({id: createdWorkflowId})
```

## Workflow Features

The Oura Sleep Score workflow provides:

- **Daily Automation**: Runs every morning at 8:00 AM
- **Smart Notifications**: Different email messages based on sleep score:
  - ✅ **Good Sleep (≥70)**: Congratulatory message with sleep breakdown
  - ⚠️ **Poor Sleep (<70)**: Alert with improvement suggestions
- **Complete Data**: Includes deep sleep, REM sleep, and light sleep durations
- **Actionable Insights**: Personalized recommendations for better sleep

### Database Query
```sql
SELECT sleep_score, date, deep_sleep_duration, rem_sleep_duration, light_sleep_duration 
FROM oura_sleep 
WHERE date = CURRENT_DATE - INTERVAL '1 day' 
ORDER BY date DESC LIMIT 1
```

## Configuration Requirements

To use the workflow management features, ensure:

1. **PostgreSQL Credential**: Configure with actual database password
2. **SMTP Credential**: Set up email provider settings (Gmail, etc.)
3. **Email Addresses**: Replace placeholder emails with actual addresses
4. **Database Schema**: Ensure `oura_sleep` table matches expected columns

## Benefits

- **Automated Daily Reports**: No manual checking required
- **Actionable Insights**: Personalized recommendations for poor sleep
- **Complete Sleep Analysis**: All key sleep metrics included
- **Flexible Scheduling**: Easy to modify trigger times
- **Extensible**: Can add more conditions, notifications, or integrations
- **Token Efficient**: Use diff operations for 80-90% token savings on updates

## Security

The deployment follows security best practices:
- Non-root user execution
- Read-only root filesystem
- Dropped Linux capabilities
- Network policies for controlled access
- Secrets managed via AWS Secrets Manager with External Secrets Operator

## Monitoring

The pod includes health checks:
- **Liveness Probe**: Ensures the Node.js process is running
- **Readiness Probe**: Confirms the server is ready to accept connections

## Troubleshooting

If the MCP server is not working:

1. Check pod status: `kubectl get pods -n mcp-servers`
2. View logs: `kubectl logs -n mcp-servers <pod-name>`
3. Verify secrets: `kubectl get secrets -n mcp-servers`
4. Test n8n connectivity: Use `n8n_health_check` tool

## Links

- [Official n8n-MCP Repository](https://github.com/czlonkowski/n8n-mcp)
- [n8n Documentation](https://docs.n8n.io/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
