# MCP Servers Documentation

This directory contains consolidated documentation for all Model Context Protocol (MCP) servers deployed in the mcp-servers namespace.

## Available MCP Servers

### [Filesystem MCP Server](./filesystem-mcp.md)
A secure MCP server that provides filesystem operations for reading, writing, and managing files within Kubernetes environments.

**Key Features:**
- Secure file operations with path validation
- Init container build pattern from ConfigMap source
- Non-root execution with namespace isolation
- Support for read, write, list, create, delete, and file info operations

### [Fetch MCP Server](./fetch-mcp.md)
A web content fetching server that retrieves and processes content from web pages, converting HTML to markdown.

**Key Features:**
- Web content fetching with HTML to markdown conversion
- Security restrictions with robots.txt compliance
- Rate limiting and chunked reading support
- Network policies for secure external access

### [GitHub MCP Server](./github-mcp.md)
Provides GitHub API integration for repository management, issue tracking, and code operations.

**Key Features:**
- GitHub API integration
- Repository and issue management
- Secure token-based authentication
- Rate limiting and API compliance

### [Kubernetes MCP Server](./kubernetes-mcp.md)
Enables Kubernetes cluster operations and resource management through MCP.

**Key Features:**
- Kubernetes API integration
- Resource management and monitoring
- RBAC-based security
- Cluster operations and diagnostics

### [Memory MCP Server](./memory-mcp.md)
Provides persistent memory and state management capabilities for MCP workflows.

**Key Features:**
- Persistent memory storage
- State management across sessions
- Data persistence with PVC storage
- Memory operations and retrieval

### [Postgres MCP Server](./postgres-mcp.md)
Database operations and SQL query execution through PostgreSQL integration.

**Key Features:**
- PostgreSQL database integration
- Secure connection management
- SQL query execution
- Database schema operations

### [Puppeteer MCP Server](./puppeteer-mcp.md)
A secure browser automation server with comprehensive security measures.

**Key Features:**
- Browser automation with Puppeteer
- Comprehensive security controls
- Domain allowlisting and network restrictions
- Resource limits and monitoring

**Security Documentation:** [Puppeteer Security Implementation](./puppeteer-security.md)

### [Sequential Thinking MCP Server](./sequentialthinking-mcp.md)
Provides structured, step-by-step reasoning and problem-solving workflows.

**Key Features:**
- Sequential reasoning capabilities
- Step-by-step problem breakdown
- Context maintenance across reasoning chains
- Result synthesis and validation

### [Time MCP Server](./time-mcp.md)
Time and timezone conversion capabilities for temporal operations.

**Key Features:**
- Current time retrieval by timezone
- Timezone conversion operations
- IANA timezone support
- Time difference calculations

### [Vector Database MCP Server](./vector-db-mcp.md)
Vector database operations for embeddings and similarity search.

**Key Features:**
- Vector storage and retrieval
- Similarity search operations
- Embedding management
- High-dimensional data operations

### [Weather MCP Server](./weather-mcp.md)
Weather data retrieval and forecasting capabilities.

**Key Features:**
- Current weather conditions
- Weather forecasting
- Location-based weather data
- Multiple weather data sources

## Getting Started

### New Server Development
For information on creating new MCP servers, see [README-new-servers.md](./README-new-servers.md).

### Common Deployment Patterns

All MCP servers in this namespace follow common patterns:

1. **Namespace Isolation**: All resources are deployed in the `mcp-servers` namespace
2. **Security Hardening**: Non-root execution, dropped capabilities, read-only filesystems
3. **Resource Management**: CPU and memory limits with appropriate requests
4. **Network Policies**: Restricted network access based on server requirements
5. **Persistent Storage**: PVC-based storage for data persistence where needed
6. **Health Monitoring**: Liveness and readiness probes for reliability

### Deployment Commands

Deploy all MCP servers:
```bash
kubectl apply -k apps/base/mcp-servers/
```

Deploy individual servers:
```bash
kubectl apply -k apps/base/mcp-servers/[server-name]/
```

Monitor deployments:
```bash
kubectl get pods -n mcp-servers
kubectl logs -n mcp-servers -l app.kubernetes.io/name=[server-name]
```

## Security Considerations

All MCP servers implement security best practices:

- **Container Security**: Non-root execution, dropped capabilities, seccomp profiles
- **Network Security**: NetworkPolicies restricting traffic based on server needs
- **Resource Limits**: CPU and memory constraints to prevent resource exhaustion
- **Access Control**: RBAC where required for Kubernetes API access
- **Data Protection**: Secure handling of secrets and sensitive data

## Troubleshooting

### Common Issues

1. **Pod Startup Issues**: Check resource limits and security contexts
2. **Network Connectivity**: Verify NetworkPolicy allows required traffic
3. **Permission Errors**: Ensure proper RBAC and security contexts
4. **Resource Exhaustion**: Monitor CPU and memory usage

### Debug Commands

```bash
# Check pod status
kubectl get pods -n mcp-servers

# View logs
kubectl logs -n mcp-servers [pod-name]

# Describe resources
kubectl describe pod -n mcp-servers [pod-name]

# Check network policies
kubectl get networkpolicies -n mcp-servers

# Monitor resource usage
kubectl top pods -n mcp-servers
```

## Contributing

When adding new MCP servers or updating existing ones:

1. Follow the established security patterns
2. Include comprehensive documentation
3. Add appropriate monitoring and health checks
4. Test in staging environment first
5. Update this index with new server information

## License

All MCP servers are part of the fako-cluster project and follow the project's licensing terms.
