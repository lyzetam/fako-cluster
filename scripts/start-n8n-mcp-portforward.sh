#!/bin/bash

# Script to start port-forward for n8n MCP server
# This ensures the MCP server is accessible locally for Claude Desktop

echo "Starting port-forward for n8n MCP server..."

# Check if port-forward is already running
if pgrep -f "kubectl port-forward.*n8n-mcp-server.*8080:3000" > /dev/null; then
    echo "Port-forward is already running"
    exit 0
fi

# Start port-forward in background
kubectl port-forward -n mcp-servers service/n8n-mcp-server 8080:3000 &

echo "Port-forward started. n8n MCP server is now accessible at http://localhost:8080"
echo "To stop: pkill -f 'kubectl port-forward.*n8n-mcp-server'"
