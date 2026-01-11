# Namespace Automation Agent

An AI-powered agent that uses natural language to create and manage Kubernetes namespaces in fako-cluster.

## Overview

This agent wraps the namespace automation tools (shell script, terraform, backstage) and exposes them as function-calling tools for use with AI models like Claude.

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Request                            │
│    "Create a new API service with ingress and secrets"          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Agent                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    System Prompt                          │  │
│  │  - Repository context                                     │  │
│  │  - Decision guidelines                                    │  │
│  │  - Best practices                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Tool Selection                          │  │
│  │  Chooses: create_namespace                                │  │
│  │  Params: {app_name: "user-api", enable_ingress: true...} │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Tool Executor                              │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────────────┐ │
│  │ Shell Script  │ │   Terraform   │ │      Backstage        │ │
│  │  create-      │ │    Module     │ │      Template         │ │
│  │  namespace.sh │ │               │ │                       │ │
│  └───────────────┘ └───────────────┘ └───────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Generated Output                            │
│  apps/base/user-api/                                            │
│  ├── namespace.yaml                                             │
│  ├── deployment.yaml                                            │
│  ├── service.yaml                                               │
│  ├── ingress.yaml                                               │
│  └── ...                                                        │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Interactive Mode

```bash
# Requires: pip install anthropic
export ANTHROPIC_API_KEY="your-key"

python namespace_agent.py --interactive
```

Example session:
```
You: Create a new backend API called order-service with database secrets

[Executing: validate_namespace]
[Executing: create_namespace]

Agent: I've created the order-service namespace with the following configuration:

- Namespace: order-service
- Component: backend
- Secrets: Enabled (AWS Secrets Manager integration)
- Files created:
  - apps/base/order-service/namespace.yaml
  - apps/base/order-service/deployment.yaml
  - apps/base/order-service/service.yaml
  - apps/base/order-service/secretstore.yaml
  - apps/base/order-service/external-secret.yaml

Next steps:
1. Update external-secret.yaml with your database credentials mapping
2. Add `- order-service` to apps/staging/kustomization.yaml
3. Commit and push to trigger FluxCD deployment
```

### Single Command

```bash
python namespace_agent.py "List all namespaces with ingress enabled"
```

### Without Anthropic SDK

You can use the tools directly or integrate with any LLM:

```python
from namespace_agent import NamespaceAgent, TOOLS

agent = NamespaceAgent()

# Execute tool directly
result = agent.execute_tool("create_namespace", {
    "app_name": "my-api",
    "enable_ingress": True,
    "enable_secrets": True,
    "component": "backend"
})
print(result)
```

## Available Tools

| Tool | Description |
|------|-------------|
| `create_namespace` | Create a single namespace with optional features |
| `list_namespaces` | List all namespaces in the repository |
| `get_namespace_details` | Get detailed info about a specific namespace |
| `validate_namespace` | Validate name and check for conflicts |
| `create_namespace_batch` | Create multiple namespaces via Terraform |
| `add_secret_mapping` | Add a new AWS secret mapping |

## Tool Definitions

The tools are defined in two formats:

### 1. YAML Format (`tools.yaml`)
Human-readable format for documentation and configuration:

```yaml
tools:
  - name: create_namespace
    description: Create a new Kubernetes namespace...
    parameters:
      type: object
      required: [app_name]
      properties:
        app_name:
          type: string
          description: Unique name for the application
```

### 2. Anthropic Format (in `namespace_agent.py`)
Ready for use with Claude's function calling:

```python
TOOLS = [
    {
        "name": "create_namespace",
        "description": "Create a new Kubernetes namespace...",
        "input_schema": {
            "type": "object",
            "required": ["app_name"],
            "properties": {
                "app_name": {
                    "type": "string",
                    "description": "Unique name for the application"
                }
            }
        }
    }
]
```

## Integration with Other Frameworks

### LangChain

```python
from langchain.tools import StructuredTool
from namespace_agent import NamespaceAgent

agent = NamespaceAgent()

create_namespace_tool = StructuredTool.from_function(
    func=lambda **kwargs: agent.execute_tool("create_namespace", kwargs),
    name="create_namespace",
    description="Create a new Kubernetes namespace"
)
```

### OpenAI Function Calling

```python
# Convert to OpenAI format
openai_tools = [
    {
        "type": "function",
        "function": {
            "name": tool["name"],
            "description": tool["description"],
            "parameters": tool["input_schema"]
        }
    }
    for tool in TOOLS
]
```

### MCP (Model Context Protocol)

The tools can be exposed as an MCP server:

```python
# See mcp_server.py for full implementation
@mcp.tool()
async def create_namespace(
    app_name: str,
    enable_ingress: bool = False,
    enable_secrets: bool = False
) -> str:
    agent = NamespaceAgent()
    result = agent.execute_tool("create_namespace", {
        "app_name": app_name,
        "enable_ingress": enable_ingress,
        "enable_secrets": enable_secrets
    })
    return json.dumps(result)
```

## System Prompt

The agent uses a specialized system prompt that includes:

1. **Repository Context**: Information about fako-cluster structure
2. **Decision Guidelines**: When to use each tool
3. **Best Practices**: Recommendations for namespace configuration

See `SYSTEM_PROMPT` in `namespace_agent.py` for the full prompt.

## Example Conversations

### Creating a Simple Service
```
User: I need a new service called metrics-collector

Agent: I'll create a simple namespace for metrics-collector. Do you need:
- External access (ingress)?
- AWS secrets integration?
- Persistent storage?
- Redis caching?

User: Just storage for the collected metrics

Agent: [Creates namespace with storage enabled]
Created metrics-collector with 10Gi storage mounted at /data.
```

### Creating a Platform
```
User: Create a new e-commerce platform with user-service, order-service,
      payment-service, and notification-worker

Agent: I'll use Terraform to create these as a batch. Here's the plan:
- user-service (backend, with ingress + secrets)
- order-service (backend, with secrets)
- payment-service (backend, with secrets)
- notification-worker (worker, with redis)

All will be labeled as part-of: ecommerce-platform

[Generates Terraform configuration]
```

## Development

### Adding New Tools

1. Add tool definition to `TOOLS` list in `namespace_agent.py`
2. Implement handler method in `NamespaceAgent` class
3. Add to `execute_tool()` dispatch table
4. Update `tools.yaml` for documentation

### Testing

```bash
# List available tools
python namespace_agent.py --list-tools

# Test with dry-run
python namespace_agent.py "Create test-app namespace"
# Agent will use dry_run=True by default for safety
```
