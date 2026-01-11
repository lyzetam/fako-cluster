#!/usr/bin/env python3
"""
MCP Server for Namespace Automation

Exposes namespace automation tools via Model Context Protocol (MCP),
allowing any MCP-compatible client to use them.

Usage:
    # Run as stdio server (for Claude Desktop, etc.)
    python mcp_server.py

    # Or with uvx
    uvx mcp run namespace-automation
"""

import json
import asyncio
from pathlib import Path
from typing import Any

# MCP SDK imports (install with: pip install mcp)
try:
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import Tool, TextContent
    HAS_MCP = True
except ImportError:
    HAS_MCP = False
    print("MCP SDK not installed. Run: pip install mcp")


# Import the agent
from namespace_agent import NamespaceAgent


def create_server() -> Server:
    """Create and configure the MCP server."""
    server = Server("namespace-automation")
    agent = NamespaceAgent()

    @server.list_tools()
    async def list_tools() -> list[Tool]:
        """List available namespace automation tools."""
        return [
            Tool(
                name="create_namespace",
                description="""Create a new Kubernetes namespace with scaffolding.

Generates deployment, service, and optional components for fako-cluster.
Use for creating individual namespaces following GitOps patterns.""",
                inputSchema={
                    "type": "object",
                    "required": ["app_name"],
                    "properties": {
                        "app_name": {
                            "type": "string",
                            "description": "Unique name (lowercase, alphanumeric, dashes)"
                        },
                        "image": {
                            "type": "string",
                            "description": "Container image"
                        },
                        "port": {
                            "type": "integer",
                            "description": "Container port",
                            "default": 8080
                        },
                        "enable_ingress": {
                            "type": "boolean",
                            "description": "Expose via ingress",
                            "default": False
                        },
                        "hostname": {
                            "type": "string",
                            "description": "Ingress hostname"
                        },
                        "enable_secrets": {
                            "type": "boolean",
                            "description": "Enable AWS Secrets Manager",
                            "default": False
                        },
                        "enable_storage": {
                            "type": "boolean",
                            "description": "Add PersistentVolumeClaim",
                            "default": False
                        },
                        "storage_size": {
                            "type": "string",
                            "description": "Storage size",
                            "default": "10Gi"
                        },
                        "enable_redis": {
                            "type": "boolean",
                            "description": "Deploy Redis cache",
                            "default": False
                        },
                        "component": {
                            "type": "string",
                            "description": "Component type",
                            "enum": ["application", "frontend", "backend", "worker", "api"]
                        },
                        "part_of": {
                            "type": "string",
                            "description": "Parent platform name"
                        },
                        "register": {
                            "type": "boolean",
                            "description": "Register in staging kustomization",
                            "default": False
                        },
                        "dry_run": {
                            "type": "boolean",
                            "description": "Preview without creating",
                            "default": False
                        }
                    }
                }
            ),
            Tool(
                name="list_namespaces",
                description="List all application namespaces in fako-cluster.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "filter": {
                            "type": "string",
                            "description": "Filter by name pattern (glob)"
                        },
                        "show_registered": {
                            "type": "boolean",
                            "description": "Only show registered namespaces",
                            "default": False
                        }
                    }
                }
            ),
            Tool(
                name="get_namespace_details",
                description="Get detailed information about a specific namespace.",
                inputSchema={
                    "type": "object",
                    "required": ["app_name"],
                    "properties": {
                        "app_name": {
                            "type": "string",
                            "description": "Namespace name"
                        }
                    }
                }
            ),
            Tool(
                name="validate_namespace",
                description="Validate namespace name and check for conflicts.",
                inputSchema={
                    "type": "object",
                    "required": ["app_name"],
                    "properties": {
                        "app_name": {
                            "type": "string",
                            "description": "Proposed namespace name"
                        }
                    }
                }
            ),
            Tool(
                name="create_namespace_batch",
                description="""Create multiple namespaces via Terraform.

Best for bulk creation when deploying a platform with multiple services.
Generates Terraform configuration for all namespaces at once.""",
                inputSchema={
                    "type": "object",
                    "required": ["namespaces"],
                    "properties": {
                        "namespaces": {
                            "type": "array",
                            "description": "List of namespace configs",
                            "items": {
                                "type": "object",
                                "required": ["app_name"],
                                "properties": {
                                    "app_name": {"type": "string"},
                                    "port": {"type": "integer"},
                                    "enable_ingress": {"type": "boolean"},
                                    "enable_secrets": {"type": "boolean"},
                                    "component": {"type": "string"}
                                }
                            }
                        },
                        "part_of": {
                            "type": "string",
                            "description": "Common platform name"
                        },
                        "plan_only": {
                            "type": "boolean",
                            "description": "Only show terraform plan",
                            "default": True
                        }
                    }
                }
            ),
            Tool(
                name="add_secret_mapping",
                description="Add a new AWS secret mapping to an existing namespace.",
                inputSchema={
                    "type": "object",
                    "required": ["app_name", "secret_key", "aws_secret_path"],
                    "properties": {
                        "app_name": {
                            "type": "string",
                            "description": "Target namespace"
                        },
                        "secret_key": {
                            "type": "string",
                            "description": "Environment variable name"
                        },
                        "aws_secret_path": {
                            "type": "string",
                            "description": "AWS Secrets Manager path"
                        },
                        "property": {
                            "type": "string",
                            "description": "JSON property in secret"
                        }
                    }
                }
            )
        ]

    @server.call_tool()
    async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
        """Execute a namespace automation tool."""
        result = agent.execute_tool(name, arguments)
        return [TextContent(
            type="text",
            text=json.dumps(result, indent=2)
        )]

    return server


async def main():
    """Run the MCP server."""
    if not HAS_MCP:
        print("Error: MCP SDK not installed")
        print("Run: pip install mcp")
        return

    server = create_server()
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream)


if __name__ == "__main__":
    asyncio.run(main())
