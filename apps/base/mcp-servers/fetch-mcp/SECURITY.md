# Security Policy for Fetch MCP Server

## Overview

The Fetch MCP Server provides web content fetching capabilities with built-in security measures to minimize risks associated with external web access.

## Security Measures

### Network Security
- **Network Policies**: Restricts egress traffic to HTTP (80), HTTPS (443), and DNS (53) only
- **No Private Network Access**: Application-level restrictions prevent access to private IP ranges
- **Ingress Control**: Only allows connections from authorized namespaces (mcp-servers, kagent)

### Container Security
- **Non-Root Execution**: Runs as user ID 1000 with dropped privileges
- **Read-Only Root Filesystem**: Prevents modification of system files (where possible)
- **No Privilege Escalation**: Container cannot escalate privileges
- **Capability Dropping**: All Linux capabilities are dropped
- **Security Context**: Enforced through Pod Security Policies

### Application Security
- **Robots.txt Compliance**: Respects website robots.txt files by default
- **Rate Limiting**: Built-in rate limiting (10 requests per 60 seconds by default)
- **Request Timeouts**: 30-second timeout prevents hanging requests
- **Content Length Limits**: Maximum 5000 characters by default
- **User Agent Identification**: Clear identification as MCP server

### Resource Security
- **Memory Limits**: 1Gi maximum memory usage
- **CPU Limits**: 500m maximum CPU usage
- **Storage Isolation**: Uses dedicated PVC for caching
- **Process Isolation**: No host network, PID, or IPC access

## Risk Assessment

### Potential Risks
1. **External Content Access**: Can fetch content from any public URL
2. **Data Exfiltration**: Could potentially be used to send data to external services
3. **Resource Consumption**: Malicious URLs could consume server resources
4. **Information Disclosure**: May reveal internal network information through error messages

### Mitigations
1. **Network Policies**: Restrict network access patterns
2. **Rate Limiting**: Prevent abuse through request throttling
3. **Resource Limits**: Prevent resource exhaustion
4. **Timeout Controls**: Prevent hanging connections
5. **Content Filtering**: Limit response sizes and types

## Configuration Security

### Environment Variables
- `FETCH_RESPECT_ROBOTS=true`: Enforces robots.txt compliance
- `FETCH_RATE_LIMIT=10`: Limits requests per window
- `FETCH_RATE_WINDOW=60000`: Rate limiting window (1 minute)
- `FETCH_TIMEOUT=30000`: Request timeout (30 seconds)
- `FETCH_MAX_LENGTH=5000`: Maximum content length

### Recommended Settings
- Keep robots.txt compliance enabled
- Use conservative rate limits
- Set appropriate timeouts
- Limit content length based on use case
- Monitor resource usage

## Monitoring and Alerting

### Recommended Monitoring
- Network traffic patterns
- Request rates and destinations
- Resource usage (CPU, memory)
- Error rates and types
- Response times

### Alert Conditions
- Unusual traffic patterns
- High error rates
- Resource limit approaches
- Repeated robots.txt violations
- Suspicious user agents or requests

## Incident Response

### Security Incident Types
1. **Abuse Detection**: Unusual request patterns or destinations
2. **Resource Exhaustion**: High CPU/memory usage
3. **Network Anomalies**: Unexpected traffic patterns
4. **Policy Violations**: Robots.txt or rate limit violations

### Response Actions
1. **Immediate**: Scale down or stop the service if needed
2. **Investigation**: Review logs and network traffic
3. **Mitigation**: Adjust rate limits or block problematic sources
4. **Recovery**: Restore service with enhanced monitoring

## Compliance

### Data Protection
- No persistent storage of fetched content (beyond caching)
- Respect for website terms of service
- Compliance with robots.txt standards
- User agent transparency

### Network Policies
- Egress restrictions to public internet only
- No access to cluster-internal services
- DNS resolution limited to necessary queries
- Monitoring of all network connections

## Updates and Maintenance

### Security Updates
- Regular updates of base container images
- Monitoring of security advisories for dependencies
- Automated vulnerability scanning
- Patch management procedures

### Configuration Reviews
- Regular review of security settings
- Rate limit effectiveness assessment
- Network policy validation
- Resource limit optimization

## Contact

For security concerns or incidents related to the Fetch MCP Server, please follow your organization's security incident response procedures.
