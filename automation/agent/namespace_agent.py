#!/usr/bin/env python3
"""
Namespace Automation Agent for fako-cluster

An AI-powered agent that uses the namespace automation tools to help users
create, manage, and configure Kubernetes namespaces through natural language.

Usage:
    python namespace_agent.py "Create a new API service called user-api with ingress and secrets"
    python namespace_agent.py --interactive
"""

import os
import json
import subprocess
import argparse
from pathlib import Path
from typing import Any

# Try to import anthropic, but make it optional for the example
try:
    import anthropic
    HAS_ANTHROPIC = True
except ImportError:
    HAS_ANTHROPIC = False


# Tool definitions for the Anthropic API
TOOLS = [
    {
        "name": "create_namespace",
        "description": """Create a new Kubernetes namespace with all required scaffolding.
Generates deployment, service, and optional components (ingress, secrets, storage, redis).
Use this for creating individual namespaces via the CLI automation script.""",
        "input_schema": {
            "type": "object",
            "required": ["app_name"],
            "properties": {
                "app_name": {
                    "type": "string",
                    "description": "Unique name for the application (lowercase, alphanumeric, dashes)"
                },
                "image": {
                    "type": "string",
                    "description": "Container image (default: ghcr.io/lzetam/<app-name>:latest)"
                },
                "port": {
                    "type": "integer",
                    "description": "Container port",
                    "default": 8080
                },
                "replicas": {
                    "type": "integer",
                    "description": "Number of pod replicas",
                    "default": 1
                },
                "enable_ingress": {
                    "type": "boolean",
                    "description": "Expose via ingress controller",
                    "default": False
                },
                "hostname": {
                    "type": "string",
                    "description": "Ingress hostname"
                },
                "enable_secrets": {
                    "type": "boolean",
                    "description": "Enable AWS Secrets Manager integration",
                    "default": False
                },
                "enable_storage": {
                    "type": "boolean",
                    "description": "Add PersistentVolumeClaim",
                    "default": False
                },
                "storage_size": {
                    "type": "string",
                    "description": "PVC size",
                    "default": "10Gi"
                },
                "enable_redis": {
                    "type": "boolean",
                    "description": "Deploy Redis for caching",
                    "default": False
                },
                "component": {
                    "type": "string",
                    "description": "Component type label",
                    "enum": ["application", "frontend", "backend", "worker", "api", "database", "cache"]
                },
                "part_of": {
                    "type": "string",
                    "description": "Parent application/platform name"
                },
                "register": {
                    "type": "boolean",
                    "description": "Auto-register in staging kustomization",
                    "default": False
                },
                "dry_run": {
                    "type": "boolean",
                    "description": "Preview without creating files",
                    "default": False
                }
            }
        }
    },
    {
        "name": "list_namespaces",
        "description": "List all application namespaces in the fako-cluster repository.",
        "input_schema": {
            "type": "object",
            "properties": {
                "filter": {
                    "type": "string",
                    "description": "Filter by name pattern"
                },
                "show_registered": {
                    "type": "boolean",
                    "description": "Only show namespaces registered in staging",
                    "default": False
                }
            }
        }
    },
    {
        "name": "get_namespace_details",
        "description": "Get detailed information about a specific namespace configuration.",
        "input_schema": {
            "type": "object",
            "required": ["app_name"],
            "properties": {
                "app_name": {
                    "type": "string",
                    "description": "Name of the namespace to inspect"
                }
            }
        }
    },
    {
        "name": "validate_namespace",
        "description": "Validate a namespace name and check for conflicts before creation.",
        "input_schema": {
            "type": "object",
            "required": ["app_name"],
            "properties": {
                "app_name": {
                    "type": "string",
                    "description": "Proposed namespace name to validate"
                }
            }
        }
    },
    {
        "name": "create_namespace_batch",
        "description": """Create multiple namespaces at once using Terraform.
Best for bulk creation when deploying a new platform with multiple services.""",
        "input_schema": {
            "type": "object",
            "required": ["namespaces"],
            "properties": {
                "namespaces": {
                    "type": "array",
                    "description": "List of namespace configurations",
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
                    "description": "Common platform name for all namespaces"
                },
                "plan_only": {
                    "type": "boolean",
                    "description": "Only show terraform plan",
                    "default": True
                }
            }
        }
    },
    {
        "name": "add_secret_mapping",
        "description": "Add a new AWS secret mapping to an existing namespace.",
        "input_schema": {
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
                    "description": "JSON property in the secret"
                }
            }
        }
    }
]

# System prompt for the agent
SYSTEM_PROMPT = """You are a Kubernetes namespace automation agent for the fako-cluster GitOps repository.

Your role is to help users create and manage Kubernetes namespaces by:
1. Understanding their application requirements
2. Choosing the appropriate automation tool (script, terraform, or backstage)
3. Executing the tool with correct parameters
4. Providing clear feedback on what was created

## Repository Context
- fako-cluster is a GitOps-managed K3s homelab with 40+ applications
- Uses FluxCD for continuous deployment from git
- Uses Kustomize for manifest management (base + staging overlays)
- Uses External Secrets Operator for AWS Secrets Manager integration
- All namespaces follow a standard pattern with consistent structure

## Decision Guidelines

**Use create_namespace (shell script) when:**
- Creating a single namespace
- User wants quick, interactive creation
- Simple configuration needs

**Use create_namespace_batch (terraform) when:**
- Creating multiple related namespaces
- User mentions a "platform" or "microservices"
- Need to track state or do bulk operations

**Always ask clarifying questions if:**
- User's intent is unclear
- Missing critical information (e.g., image name for production apps)
- Potentially destructive operation

## Best Practices
1. Validate namespace names before creation
2. Suggest enabling secrets for production apps
3. Recommend ingress for user-facing services
4. Use meaningful component labels (frontend, backend, worker, api)
5. Group related services with part_of labels

Be concise but informative. After tool execution, summarize what was created and next steps."""


class NamespaceAgent:
    """Agent that uses namespace automation tools via function calling."""

    def __init__(self, repo_root: str = None):
        self.repo_root = Path(repo_root or self._find_repo_root())
        self.automation_dir = self.repo_root / "automation"
        self.apps_base = self.repo_root / "apps" / "base"
        self.apps_staging = self.repo_root / "apps" / "staging"

    def _find_repo_root(self) -> Path:
        """Find the repository root directory."""
        current = Path(__file__).parent
        while current != current.parent:
            if (current / ".git").exists():
                return current
            current = current.parent
        return Path.cwd()

    def execute_tool(self, tool_name: str, tool_input: dict) -> dict:
        """Execute a tool and return the result."""
        handlers = {
            "create_namespace": self._create_namespace,
            "list_namespaces": self._list_namespaces,
            "get_namespace_details": self._get_namespace_details,
            "validate_namespace": self._validate_namespace,
            "create_namespace_batch": self._create_namespace_batch,
            "add_secret_mapping": self._add_secret_mapping,
        }

        handler = handlers.get(tool_name)
        if not handler:
            return {"error": f"Unknown tool: {tool_name}"}

        try:
            return handler(tool_input)
        except Exception as e:
            return {"error": str(e)}

    def _create_namespace(self, params: dict) -> dict:
        """Execute the create-namespace.sh script."""
        script = self.automation_dir / "create-namespace.sh"

        cmd = [str(script), params["app_name"]]

        # Map parameters to CLI flags
        if params.get("image"):
            cmd.extend(["--image", params["image"]])
        if params.get("port"):
            cmd.extend(["--port", str(params["port"])])
        if params.get("replicas"):
            cmd.extend(["--replicas", str(params["replicas"])])
        if params.get("enable_ingress"):
            cmd.append("--with-ingress")
        if params.get("hostname"):
            cmd.extend(["--host", params["hostname"]])
        if params.get("enable_secrets"):
            cmd.append("--with-secrets")
        if params.get("enable_storage"):
            cmd.append("--with-storage")
        if params.get("storage_size"):
            cmd.extend(["--storage-size", params["storage_size"]])
        if params.get("enable_redis"):
            cmd.append("--with-redis")
        if params.get("component"):
            cmd.extend(["--component", params["component"]])
        if params.get("part_of"):
            cmd.extend(["--part-of", params["part_of"]])
        if params.get("register"):
            cmd.append("--register")
        if params.get("dry_run"):
            cmd.append("--dry-run")

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=self.repo_root
        )

        return {
            "success": result.returncode == 0,
            "output": result.stdout,
            "error": result.stderr if result.returncode != 0 else None,
            "command": " ".join(cmd)
        }

    def _list_namespaces(self, params: dict) -> dict:
        """List all namespaces in the repository."""
        namespaces = []

        # Scan apps/base directory
        if self.apps_base.exists():
            for app_dir in sorted(self.apps_base.iterdir()):
                if app_dir.is_dir() and (app_dir / "namespace.yaml").exists():
                    ns_info = {"name": app_dir.name, "has_base": True}

                    # Check what features are enabled
                    ns_info["has_ingress"] = (app_dir / "ingress.yaml").exists()
                    ns_info["has_secrets"] = (app_dir / "secretstore.yaml").exists()
                    ns_info["has_storage"] = (app_dir / "storage.yaml").exists()
                    ns_info["has_redis"] = (app_dir / "redis.yaml").exists()

                    # Check if registered in staging
                    staging_dir = self.apps_staging / app_dir.name
                    ns_info["registered"] = staging_dir.exists()

                    # Apply filter if provided
                    if params.get("filter"):
                        import fnmatch
                        if not fnmatch.fnmatch(app_dir.name, params["filter"]):
                            continue

                    if params.get("show_registered") and not ns_info["registered"]:
                        continue

                    namespaces.append(ns_info)

        return {
            "count": len(namespaces),
            "namespaces": namespaces
        }

    def _get_namespace_details(self, params: dict) -> dict:
        """Get detailed information about a namespace."""
        app_name = params["app_name"]
        base_dir = self.apps_base / app_name

        if not base_dir.exists():
            return {"error": f"Namespace '{app_name}' not found"}

        details = {
            "name": app_name,
            "base_path": str(base_dir),
            "files": [],
            "features": {}
        }

        # List all YAML files
        for yaml_file in base_dir.glob("*.yaml"):
            details["files"].append(yaml_file.name)

        # Detect features
        details["features"]["ingress"] = (base_dir / "ingress.yaml").exists()
        details["features"]["secrets"] = (base_dir / "secretstore.yaml").exists()
        details["features"]["storage"] = (base_dir / "storage.yaml").exists()
        details["features"]["redis"] = (base_dir / "redis.yaml").exists()

        # Check staging registration
        staging_kustomization = self.apps_staging / "kustomization.yaml"
        if staging_kustomization.exists():
            content = staging_kustomization.read_text()
            details["registered"] = f"- {app_name}" in content

        # Try to extract image from deployment
        deployment_file = base_dir / "deployment.yaml"
        if deployment_file.exists():
            import re
            content = deployment_file.read_text()
            match = re.search(r'image:\s*(\S+)', content)
            if match:
                details["image"] = match.group(1)

        return details

    def _validate_namespace(self, params: dict) -> dict:
        """Validate a namespace name and check for conflicts."""
        import re

        app_name = params["app_name"]
        issues = []

        # Check naming convention
        if not re.match(r'^[a-z][a-z0-9-]*[a-z0-9]$|^[a-z]$', app_name):
            issues.append("Name must be lowercase alphanumeric with dashes, starting with a letter")

        # Check length
        if len(app_name) > 63:
            issues.append("Name exceeds 63 character limit for Kubernetes namespaces")

        # Check for existing namespace
        if (self.apps_base / app_name).exists():
            issues.append(f"Namespace '{app_name}' already exists in apps/base/")

        # Check for reserved names
        reserved = ["default", "kube-system", "kube-public", "kube-node-lease", "flux-system"]
        if app_name in reserved:
            issues.append(f"'{app_name}' is a reserved Kubernetes namespace")

        return {
            "valid": len(issues) == 0,
            "app_name": app_name,
            "issues": issues
        }

    def _create_namespace_batch(self, params: dict) -> dict:
        """Generate Terraform configuration for multiple namespaces."""
        namespaces = params["namespaces"]
        part_of = params.get("part_of", "platform")

        # Generate Terraform module calls
        tf_config = []
        for ns in namespaces:
            module_name = ns["app_name"].replace("-", "_")
            tf_config.append(f'''
module "{module_name}" {{
  source = "./modules/namespace"

  app_name       = "{ns['app_name']}"
  port           = {ns.get('port', 8080)}
  enable_ingress = {str(ns.get('enable_ingress', False)).lower()}
  enable_secrets = {str(ns.get('enable_secrets', False)).lower()}
  component      = "{ns.get('component', 'application')}"
  part_of        = "{part_of}"
}}''')

        tf_content = "\n".join(tf_config)

        if params.get("plan_only", True):
            return {
                "action": "plan",
                "namespace_count": len(namespaces),
                "terraform_config": tf_content,
                "instructions": [
                    "1. Add the above to terraform/main.tf",
                    "2. Run: cd terraform && terraform init",
                    "3. Run: terraform plan",
                    "4. Run: terraform apply",
                    "5. Register namespaces in apps/staging/kustomization.yaml"
                ]
            }

        # Actually write the config (not implemented for safety)
        return {
            "action": "generated",
            "namespace_count": len(namespaces),
            "terraform_config": tf_content
        }

    def _add_secret_mapping(self, params: dict) -> dict:
        """Add a secret mapping to an existing namespace."""
        app_name = params["app_name"]
        secret_key = params["secret_key"]
        aws_path = params["aws_secret_path"]
        prop = params.get("property", "")

        external_secret = self.apps_base / app_name / "external-secret.yaml"

        if not external_secret.exists():
            return {
                "error": f"No external-secret.yaml found for '{app_name}'. Enable secrets first."
            }

        # Generate the new mapping
        mapping = f"""    - secretKey: {secret_key}
      remoteRef:
        key: {aws_path}"""
        if prop:
            mapping += f"\n        property: {prop}"

        return {
            "success": True,
            "file": str(external_secret),
            "mapping_to_add": mapping,
            "instructions": [
                f"Add the following to {external_secret} under spec.data:",
                mapping
            ]
        }


def run_interactive(agent: NamespaceAgent):
    """Run the agent in interactive mode with the Anthropic API."""
    if not HAS_ANTHROPIC:
        print("Error: anthropic package not installed. Run: pip install anthropic")
        return

    client = anthropic.Anthropic()
    messages = []

    print("Namespace Automation Agent")
    print("=" * 40)
    print("Type your request or 'quit' to exit.\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            break

        if user_input.lower() in ["quit", "exit", "q"]:
            break

        if not user_input:
            continue

        messages.append({"role": "user", "content": user_input})

        # Call Claude with tools
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages
        )

        # Process response and tool calls
        while response.stop_reason == "tool_use":
            # Extract tool use blocks
            tool_results = []
            assistant_content = response.content

            for block in response.content:
                if block.type == "tool_use":
                    print(f"\n[Executing: {block.name}]")
                    result = agent.execute_tool(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result, indent=2)
                    })

            # Continue conversation with tool results
            messages.append({"role": "assistant", "content": assistant_content})
            messages.append({"role": "user", "content": tool_results})

            response = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=4096,
                system=SYSTEM_PROMPT,
                tools=TOOLS,
                messages=messages
            )

        # Print final response
        assistant_message = ""
        for block in response.content:
            if hasattr(block, "text"):
                assistant_message += block.text

        messages.append({"role": "assistant", "content": response.content})
        print(f"\nAgent: {assistant_message}\n")


def run_single(agent: NamespaceAgent, prompt: str):
    """Run a single prompt through the agent."""
    if not HAS_ANTHROPIC:
        print("Error: anthropic package not installed. Run: pip install anthropic")
        return

    client = anthropic.Anthropic()
    messages = [{"role": "user", "content": prompt}]

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        tools=TOOLS,
        messages=messages
    )

    # Process tool calls
    while response.stop_reason == "tool_use":
        tool_results = []

        for block in response.content:
            if block.type == "tool_use":
                print(f"[Executing: {block.name}]")
                result = agent.execute_tool(block.name, block.input)
                print(json.dumps(result, indent=2))
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": json.dumps(result)
                })

        messages.append({"role": "assistant", "content": response.content})
        messages.append({"role": "user", "content": tool_results})

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages
        )

    # Print final response
    for block in response.content:
        if hasattr(block, "text"):
            print(f"\n{block.text}")


def main():
    parser = argparse.ArgumentParser(
        description="Namespace Automation Agent for fako-cluster"
    )
    parser.add_argument(
        "prompt",
        nargs="?",
        help="Natural language prompt for namespace operation"
    )
    parser.add_argument(
        "--interactive", "-i",
        action="store_true",
        help="Run in interactive mode"
    )
    parser.add_argument(
        "--repo-root",
        help="Path to the fako-cluster repository"
    )
    parser.add_argument(
        "--list-tools",
        action="store_true",
        help="List available tools and exit"
    )

    args = parser.parse_args()
    agent = NamespaceAgent(repo_root=args.repo_root)

    if args.list_tools:
        print("Available Tools:")
        print("=" * 40)
        for tool in TOOLS:
            print(f"\n{tool['name']}")
            print(f"  {tool['description'].strip().split(chr(10))[0]}")
        return

    if args.interactive:
        run_interactive(agent)
    elif args.prompt:
        run_single(agent, args.prompt)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
