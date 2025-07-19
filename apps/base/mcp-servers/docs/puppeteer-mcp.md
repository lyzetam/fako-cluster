# Puppeteer MCP Server

A secure Model Context Protocol server that provides browser automation capabilities using Puppeteer with comprehensive security guard rails.

## ⚠️ Security Notice

This server provides browser automation capabilities and has been deployed with extensive security measures to mitigate risks. However, it still requires careful usage and monitoring.

### Security Risks Addressed

1. **Local File Access**: Prevented through read-only root filesystem and restricted volume mounts
2. **Internal Network Access**: Blocked via NetworkPolicy preventing access to private IP ranges
3. **Privilege Escalation**: Prevented through PodSecurityPolicy and container security contexts
4. **Resource Exhaustion**: Limited through resource quotas and browser process limits

## Security Measures Implemented

### Container Security
- **Non-root execution**: Runs as user/group 1000
- **Read-only root filesystem**: Prevents file system modifications
- **No privilege escalation**: Explicitly disabled
- **Dropped capabilities**: All Linux capabilities removed
- **Seccomp profile**: Runtime default security profile applied

### Network Security
- **NetworkPolicy**: Restricts ingress/egress traffic
- **Private IP blocking**: Prevents access to RFC 1918 private networks
- **Domain allowlist**: Only specified domains are accessible
- **DNS restrictions**: Limited to necessary DNS resolution

### Resource Limits
- **Memory**: 512Mi request, 2Gi limit
- **CPU**: 200m request, 1000m limit
- **Browser processes**: Maximum 5 pages per instance
- **Timeouts**: 30-second navigation and page timeouts

### Application-Level Controls
- **Headless mode**: Enforced browser headless operation
- **Dangerous options disabled**: `ALLOW_DANGEROUS=false`
- **Sandbox restrictions**: Browser runs with security sandbox
- **Local access prevention**: `PUPPETEER_DISABLE_LOCAL_ACCESS=true`

## Configuration

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `PUPPETEER_LAUNCH_OPTIONS` | Secure browser args | Enforces safe browser configuration |
| `ALLOW_DANGEROUS` | `false` | Prevents dangerous launch options |
| `PUPPETEER_DISABLE_LOCAL_ACCESS` | `true` | Blocks local file/network access |
| `PUPPETEER_ALLOWED_DOMAINS` | Domain allowlist | Restricts accessible domains |
| `PUPPETEER_MAX_PAGES` | `5` | Limits concurrent browser pages |
| `PUPPETEER_PAGE_TIMEOUT` | `30000` | Page operation timeout (ms) |
| `PUPPETEER_NAVIGATION_TIMEOUT` | `30000` | Navigation timeout (ms) |

### Allowed Domains

Currently configured to allow:
- `*.example.com`
- `*.trusted-site.com`

**To modify allowed domains**, update the `PUPPETEER_ALLOWED_DOMAINS` environment variable in the deployment.

## Available Tools

- **puppeteer_navigate**: Navigate to URLs (restricted by domain allowlist)
- **puppeteer_screenshot**: Capture page screenshots
- **puppeteer_click**: Click page elements
- **puppeteer_hover**: Hover over elements
- **puppeteer_fill**: Fill form inputs
- **puppeteer_select**: Select dropdown options
- **puppeteer_evaluate**: Execute JavaScript (sandboxed)

## Resources

- **Console Logs**: `console://logs` - Browser console output
- **Screenshots**: `screenshot://<name>` - Captured screenshots

## Monitoring and Alerts

### Health Checks
- **Liveness probe**: `/health` endpoint (30s intervals)
- **Readiness probe**: `/ready` endpoint (10s intervals)

### Recommended Monitoring
- Monitor resource usage (CPU/Memory)
- Track network connections and destinations
- Log browser navigation attempts
- Alert on policy violations

## Usage Guidelines

### ✅ Recommended Uses
- Automated testing of public websites
- Web scraping from approved domains
- Screenshot generation for documentation
- Form automation on trusted sites

### ❌ Prohibited Uses
- Accessing internal/private networks
- Bypassing authentication systems
- Scraping sensitive or personal data
- Accessing localhost or private IPs
- Running untrusted JavaScript code

## Deployment

The server is deployed with the following Kubernetes resources:
- `Deployment`: Main application deployment with security contexts
- `Service`: ClusterIP service for internal access
- `NetworkPolicy`: Network traffic restrictions
- `PodSecurityPolicy`: Pod-level security enforcement

## Troubleshooting

### Common Issues

1. **Navigation Blocked**: Check if domain is in allowlist
2. **Timeout Errors**: Verify page load times are under 30 seconds
3. **Resource Limits**: Monitor CPU/memory usage
4. **Network Errors**: Check NetworkPolicy allows required traffic

### Logs

Check container logs for detailed error information:
```bash
kubectl logs -n mcp-servers deployment/puppeteer-mcp-server
```

## Security Updates

This deployment should be regularly reviewed and updated to:
- Update browser versions for security patches
- Review and update domain allowlists
- Monitor for new security vulnerabilities
- Adjust resource limits based on usage patterns

## Compliance

This deployment implements security controls aligned with:
- Kubernetes Pod Security Standards (Restricted)
- OWASP Container Security Guidelines
- CIS Kubernetes Benchmark recommendations
