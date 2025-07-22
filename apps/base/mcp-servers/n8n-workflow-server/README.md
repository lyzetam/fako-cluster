# N8N Workflow Library MCP Server

This MCP server provides Claude Desktop with access to a rich library of 2,053 N8N workflow templates, enabling Claude to search, analyze, and suggest workflows when helping you create automations.

## Features

The server provides the following tools:

- **search_workflows**: Search workflows by text, trigger type, complexity, or category
- **get_workflow_details**: Get detailed information about a specific workflow
- **download_workflow**: Download workflow JSON for import into N8N
- **get_workflow_stats**: View library statistics (2,053 workflows, 365 integrations)
- **list_categories**: Browse 12 service categories (messaging, AI/ML, database, etc.)
- **get_workflows_by_integration**: Find all workflows using a specific service

## Workflow Library Contents

- **Total Workflows**: 2,053 automation templates
- **Active Workflows**: 215 (10.5% active rate)
- **Total Nodes**: 29,445 (avg 14.3 nodes per workflow)
- **Unique Integrations**: 365 different services and APIs

### Categories Available:
- messaging (Telegram, Discord, Slack, WhatsApp)
- ai_ml (OpenAI, Anthropic, Hugging Face)
- database (PostgreSQL, MySQL, MongoDB, Airtable)
- email (Gmail, Mailjet, Outlook)
- cloud_storage (Google Drive, Dropbox)
- project_management (Jira, GitHub, GitLab)
- social_media (LinkedIn, Twitter/X)
- ecommerce (Shopify, Stripe, PayPal)
- analytics (Google Analytics, Mixpanel)
- calendar_tasks (Google Calendar, Calendly)
- forms (Typeform, Google Forms)
- development (Webhook, HTTP Request, GraphQL)

## Configuration

### 1. Deploy Workflow Library API (if not already running)

The MCP server expects the workflow library API to be running. You can either:

a) Run it locally:
```bash
git clone <workflow-library-repo>
cd n8n-workflows
pip install -r requirements.txt
python run.py  # Runs on http://localhost:8000
```

b) Or deploy it to Kubernetes and update the WORKFLOW_API_URL in the deployment

### 2. Deploy the MCP Server

```bash
kubectl apply -k apps/base/mcp-servers/n8n-workflow-server/
```

### 3. Configure Claude Desktop

The configuration is already added to your Claude Desktop config:

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

## Usage Examples

Once configured, Claude can help you find and create workflows:

1. **Find messaging workflows:**
   ```
   "Show me Telegram bot workflows"
   "Find Discord automation templates"
   ```

2. **Search by complexity:**
   ```
   "Find simple workflows with less than 5 nodes"
   "Show me complex enterprise workflows"
   ```

3. **Browse categories:**
   ```
   "What AI/ML workflow templates are available?"
   "Show me all database integration workflows"
   ```

4. **Get specific workflow:**
   ```
   "Get details for workflow 0001_Telegram_Bot_Webhook.json"
   "Download the workflow template for Telegram automation"
   ```

## Architecture

This MCP server follows the GitOps pattern:
- Source code is stored in a ConfigMap
- No external dependencies or Docker registry required
- Connects to the workflow library API for template access
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

3. **Test MCP server directly:**
   ```bash
   kubectl exec -it -n mcp-servers deployment/n8n-workflow-server -- python /app/server.py
   ```

4. **Verify workflow library API connectivity:**
   ```bash
   kubectl exec -n mcp-servers deployment/n8n-workflow-server -- \
     curl -s http://n8n-workflow-library.default.svc.cluster.local:8000/api/stats
   ```

## How Claude Uses This

When you ask Claude to help create an N8N workflow, Claude can:
1. Search the library for similar workflows
2. Analyze existing templates for best practices
3. Suggest modifications based on proven patterns
4. Provide complete workflow JSON ready for import

This gives Claude contextual knowledge of 2,053 real-world workflow patterns across 365 integrations!
