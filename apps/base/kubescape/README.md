# Kubescape Security Scanner

This directory contains the Kubernetes manifests for deploying Kubescape, a comprehensive Kubernetes security posture management tool that provides security scanning, compliance checking, and a web interface for viewing results.

## Overview

Kubescape is deployed as a persistent service that continuously scans the Kubernetes cluster for security issues, misconfigurations, and compliance violations. It includes a web UI accessible via ingress for easy viewing of scan results.

## Components

- **Namespace**: `kubescape` (dedicated namespace for Kubescape)
- **ServiceAccount**: `kubescape` with comprehensive cluster read permissions
- **ClusterRole**: Broad permissions to scan all cluster resources
- **PersistentVolumeClaim**: 10Gi storage for historical scan results
- **Deployment**: Dual-container deployment with Kubescape scanner and Nginx web server
- **Service**: ClusterIP service exposing web UI (port 80) and API (port 8080)
- **Ingress**: External access via `kubescape.landryzetam.net`

## Features

- **Comprehensive Security Scanning**: 
  - CIS Kubernetes Benchmark compliance
  - NIST Cybersecurity Framework
  - NSA/CISA Kubernetes Hardening Guide
  - MITRE ATT&CK framework checks
- **Web Dashboard**: Simple HTML interface for viewing scan results
- **Persistent Storage**: Historical scan results with timestamps
- **Automated Scanning**: Initial scan on startup, then hourly scans
- **API Access**: RESTful API for programmatic access to results
- **JSON Output**: Machine-readable scan results

## Architecture

### Kubescape Container
- **Image**: `quay.io/kubescape/kubescape:latest`
- **Function**: Performs security scans and serves API
- **Resources**: 512Mi-1Gi memory, 200m-500m CPU
- **Storage**: Writes scan results to persistent volume

### Web UI Container  
- **Image**: `nginx:alpine`
- **Function**: Serves web dashboard and scan results
- **Resources**: 64Mi-128Mi memory, 50m-100m CPU
- **Features**: Auto-refresh, JSON file browsing, health checks

## Access Methods

### Web Dashboard
- **URL**: https://kubescape.landryzetam.net
- **Features**: 
  - View all historical scan results
  - Download JSON files
  - Real-time health status
  - Auto-refresh every 30 seconds

### Direct API Access
- **Port Forward**: `kubectl port-forward -n kubescape service/kubescape 8080:8080`
- **API Endpoint**: http://localhost:8080
- **Health Check**: http://localhost:8080/health

### Command Line Access
```bash
# View latest scan results
kubectl logs -n kubescape deployment/kubescape -c kubescape --tail=100

# Access stored results via temporary pod
kubectl run -n kubescape tmp-access --image=busybox:latest --rm -it --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"tmp-access","image":"busybox:latest","command":["sh"],"volumeMounts":[{"name":"results","mountPath":"/results"}]}],"volumes":[{"name":"results","persistentVolumeClaim":{"claimName":"kubescape-results"}}]}}' \
  -- sh

# Inside the pod:
ls -la /results/
cat /results/scan-YYYYMMDD-HHMMSS.json
```

## Scan Results Format

Results are stored as timestamped JSON files:
- **Format**: `scan-YYYYMMDD-HHMMSS.json` or `initial-scan-YYYYMMDD-HHMMSS.json`
- **Content**: Detailed security findings, compliance scores, and remediation guidance
- **Structure**: JSON with severity levels, resource details, and fix recommendations

## Security Considerations

- **Privileged Access**: ClusterRole provides broad read access to all resources
- **Network Exposure**: Ingress exposes dashboard publicly (configure authentication as needed)
- **Storage**: Scan results may contain sensitive cluster information
- **Resource Usage**: Scans can be resource-intensive on large clusters

## Configuration

### Scan Frequency
Modify the sleep interval in `deployment.yaml`:
```yaml
sleep 3600  # 3600 = 1 hour, 1800 = 30 minutes
```

### Resource Limits
Adjust container resources based on cluster size:
```yaml
resources:
  requests:
    memory: "512Mi"  # Increase for larger clusters
    cpu: "200m"
  limits:
    memory: "1Gi"    # Increase for larger clusters  
    cpu: "500m"
```

### Storage Size
Modify PVC size in `storage.yaml`:
```yaml
resources:
  requests:
    storage: 10Gi  # Adjust based on retention needs
```

## Manual Operations

### Run Manual Scan
```bash
kubectl create job --from=cronjob/manual-kubescape-scan -n kubescape manual-scan-$(date +%s)
```

### View Current Status
```bash
kubectl get pods -n kubescape
kubectl describe deployment/kubescape -n kubescape
```

### Access Logs
```bash
# Scanner logs
kubectl logs -n kubescape deployment/kubescape -c kubescape -f

# Web server logs  
kubectl logs -n kubescape deployment/kubescape -c web-ui -f
```

## Troubleshooting

### Common Issues

1. **Scanner Not Starting**: Check RBAC permissions and cluster connectivity
2. **No Scan Results**: Verify PVC is mounted and writable
3. **Web UI Not Accessible**: Check ingress configuration and DNS
4. **High Resource Usage**: Reduce scan frequency or increase resource limits

### Health Checks
- **Web UI**: https://kubescape.landryzetam.net/health
- **API**: Port-forward and access http://localhost:8080/health
- **Pod Status**: `kubectl get pods -n kubescape`

## Integration

Kubescape can be integrated with:
- **CI/CD Pipelines**: Use scan results for security gates
- **Monitoring Systems**: Parse JSON results for alerting
- **GitOps**: Results can inform security policy updates
- **Compliance Reporting**: Generate compliance reports from scan data

This deployment provides a comprehensive, always-on security scanning solution with an accessible web interface for your Kubernetes cluster.
