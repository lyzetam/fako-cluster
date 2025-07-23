# Kubescape Operator with Headlamp Integration

This directory contains the proper Kubescape deployment using the Kubescape Operator, which provides comprehensive security scanning with a full-featured UI through Headlamp integration.

## Architecture

```
┌─────────────────────────────┐
│   Kubescape Operator        │
├─────────────────────────────┤
│ - Continuous scanning       │
│ - Network policy service    │
│ - Vulnerability scanning    │
│ - Compliance frameworks     │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   Storage (NFS)             │
├─────────────────────────────┤
│ - Scan results              │
│ - Vulnerability data        │
│ - Network policies          │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   Headlamp Dashboard        │
├─────────────────────────────┤
│ - Kubescape plugin          │
│ - Visual compliance view    │
│ - Network policy graphs     │
│ - CEL policy playground     │
└─────────────────────────────┘
```

## Features

### Kubescape Operator
- **Continuous Scanning**: Real-time security monitoring
- **Framework Compliance**: NSA, MITRE, CIS benchmarks
- **Vulnerability Scanning**: Container image vulnerability detection
- **Network Policies**: Automatic network policy generation
- **SBOM Generation**: Software Bill of Materials for containers

### Headlamp Integration
- **Visual Dashboard**: Graphical representation of security findings
- **Compliance Overview**: Framework compliance scores and details
- **Network Policy Visualization**: Interactive network policy graphs
- **Vulnerability Explorer**: Browse and filter vulnerabilities
- **CEL Policy Playground**: Test admission policies

## Configuration

The operator is configured with:
- Continuous scanning enabled
- Network policy service enabled
- Multiple compliance frameworks (NSA, MITRE, CIS)
- Prometheus metrics enabled
- Dedicated security logs storage

## Usage

### Accessing Headlamp
1. Navigate to https://headlamp.landryzetam.net
2. Login with your Kubernetes credentials
3. Install the Kubescape plugin:
   - Go to Settings → Plugins
   - Search for "kubescape"
   - Click Install

### Viewing Security Data
Once the plugin is installed:
- **Compliance**: View framework compliance scores
- **Vulnerabilities**: Browse container vulnerabilities
- **Network Policies**: See generated network policies
- **Workload Security**: Per-workload security posture

### Manual Scans
While continuous scanning is enabled, you can trigger manual scans:
```bash
kubectl exec -n kubescape deployment/kubescape-operator -- kubescape scan framework nsa
```

## Storage

The operator uses the `nfs-security-logs` storage class for persistent storage of:
- Scan results
- Vulnerability databases
- Generated network policies
- SBOM data

## Monitoring

Prometheus metrics are exposed and can be scraped for:
- Scan completion status
- Vulnerability counts
- Compliance scores
- Operator health

## Troubleshooting

Check operator status:
```bash
kubectl get pods -n kubescape
kubectl logs -n kubescape deployment/kubescape-operator
```

Check scanning jobs:
```bash
kubectl get jobs -n kubescape
kubectl get cronjobs -n kubescape
```

## References
- [Kubescape Documentation](https://hub.armosec.io/docs)
- [Headlamp Documentation](https://headlamp.dev/)
- [Kubescape Headlamp Plugin](https://github.com/kubescape/headlamp-plugin)
