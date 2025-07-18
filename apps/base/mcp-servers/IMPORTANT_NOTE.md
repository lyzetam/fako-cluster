# IMPORTANT: MCP Server Placeholder Setup

## Current Status

The MCP server deployments currently use **nginx:alpine** as placeholder images because the actual MCP server images referenced in the documentation are not publicly available or may have compatibility issues.

## What This Means

1. **The pods will now deploy successfully** - You'll see MCP server pods running in the `mcp-servers` namespace
2. **Tool discovery annotations are configured** - The services have the proper Kagent annotations
3. **The infrastructure is ready** - RBAC, service accounts, and networking are all properly configured
4. **But the MCP functionality won't work** - Since these are just nginx placeholders, not actual MCP servers

## How to Add Real MCP Servers

When you have access to working MCP server images:

1. Update the deployment files to use the real images:
   - `apps/base/mcp-servers/kubernetes-mcp/deployment.yaml`
   - `apps/base/mcp-servers/website-fetcher-mcp/deployment.yaml`

2. Replace the nginx:alpine image with your MCP server image
3. Update the container ports, environment variables, and health checks as needed
4. Apply the changes: `kubectl apply -k apps/staging/mcp-servers/`

## Example MCP Server Images to Try

Based on the MCP ecosystem, you might try:
- Build your own from: https://github.com/modelcontextprotocol/servers
- Use community images when they become available
- Create custom MCP servers following the MCP specification

## Why This Approach?

This placeholder approach allows you to:
- Test the deployment infrastructure
- Verify the Kagent integration setup
- Have a working template ready for real MCP servers
- Demonstrate the pattern for adding MCP servers to your cluster

## Next Steps

1. The agents (`k8s-operator` and `web-analyzer`) are configured to use these MCP servers
2. Once you replace the placeholder images with real MCP servers, the agents will automatically start using them
3. The tool discovery mechanism will work as soon as real MCP servers are deployed
