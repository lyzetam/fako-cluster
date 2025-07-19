# Sequential Thinking MCP Server

The Sequential Thinking MCP (Model Context Protocol) server provides tools and resources for structured, step-by-step reasoning and problem-solving workflows.

## Overview

This MCP server implements sequential thinking capabilities that help break down complex problems into manageable steps, track reasoning chains, and maintain context across multi-step processes.

## Features

### Tools
- **sequential_analyze**: Break down complex problems into sequential steps
- **step_execute**: Execute individual steps in a reasoning chain
- **context_maintain**: Maintain context and state across reasoning steps
- **chain_validate**: Validate the logical flow of reasoning chains
- **result_synthesize**: Combine results from multiple reasoning steps

### Resources
- **thinking_chains**: Access to stored reasoning chains and patterns
- **step_templates**: Pre-defined templates for common reasoning patterns
- **context_history**: Historical context and state information

## Configuration

The server runs as a Kubernetes deployment with:
- **Image**: `mcp/sequentialthinking:latest`
- **Resources**: 256Mi-1Gi memory, 100m-500m CPU
- **Storage**: 2Gi persistent volume for data persistence
- **Port**: 3000 (HTTP service)

## Usage

The server provides stdio-based MCP communication for integration with AI assistants and reasoning systems. It maintains persistent storage for reasoning chains and context history.

## Environment Variables

- `NODE_ENV`: Set to "production" for production deployments
- `MCP_SERVER_NAME`: Set to "sequentialthinking" for identification

## Deployment

This server is deployed as part of the mcp-servers namespace and is managed through Kustomize configurations.
