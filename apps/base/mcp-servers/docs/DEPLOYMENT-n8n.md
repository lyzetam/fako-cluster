# n8n MCP Server Deployment Guide

## Prerequisites

1. **n8n instance running** in your cluster (✅ Already deployed)
2. **n8n API key** with administrative privileges
3. **Network connectivity** between mcp-servers and n8n namespaces

## Step-by-Step Deployment

### 1. Get n8n API Key

1. Access your n8n instance at `https://n8n.landryzetam.net`
2. Log in with your credentials
3. Navigate to **Settings** → **API Keys**
4. Click **Create API Key**
5. Name it "MCP Server" or similar
6. Copy the generated API key (save it securely)

### 2. Update AWS Secret with n8n API Key

The n8n MCP server uses External Secrets Operator to pull the API key from AWS Secrets Manager. You need to update the AWS secret `n8n/api-keys` with your actual n8n API key:

```bash
# Update the AWS secret with your actual n8n API key
aws secretsmanager update-secret \
  --secret-id "n8n/api-keys" \
  --secret-string '{"N8N_API_KEYS":"your-actual-n8n-api-key-here"}' \
  --region us-east-1
```

The current value `"dummy-ollama-key-not-used"` needs to be replaced with a real n8n API key.

### 3. Deploy the n8n MCP Server

```bash
# Deploy the server
kubectl apply -k apps/base/mcp-servers/n8n-mcp/

# Expected output:
# secret/n8n-mcp-secret created
# configmap/n8n-mcp-server-config created
# service/n8n-mcp-server created
# deployment.apps/n8n-mcp-server created
# networkpolicy.networking.k8s.io/n8n-mcp-server-netpol created
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# n8n-mcp-server-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

# Check logs
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# Should show npm install completion and server ready
```

### 5. Test Connectivity

```bash
# Test connection to n8n service
kubectl exec -n mcp-servers deployment/n8n-mcp-server -- wget -qO- http://n8n.n8n.svc.cluster.local:5678/healthz

# Expected output: OK or similar health check response

# Test n8n API with authentication
kubectl exec -n mcp-servers deployment/n8n-mcp-server -- sh -c 'curl -H "X-N8N-API-KEY: $N8N_API_KEY" $N8N_URL/api/v1/workflows'

# Should return JSON with workflows list (may be empty initially)
```

### 6. Update Main MCP Servers (Already Done)

The main kustomization file has been updated to include n8n-mcp:

```yaml
# apps/base/mcp-servers/kustomization.yaml
resources:
  # ... other servers ...
  - n8n-mcp  # ✅ Added
```

### 7. Deploy All MCP Servers

```bash
# Deploy all MCP servers including n8n
kubectl apply -k apps/base/mcp-servers/

# Verify all servers are running
kubectl get pods -n mcp-servers
```

## Integration with kagent

Once deployed, you'll need to configure kagent to use the n8n MCP server. The server will be available at:

- **Service**: `n8n-mcp-server.mcp-servers.svc.cluster.local:3000`
- **Protocol**: stdio (MCP standard)

## Testing the MCP Server

### Manual Test

```bash
# Access the pod
kubectl exec -it -n mcp-servers deployment/n8n-mcp-server -- sh

# Inside the pod, test the MCP server
cd /app
node server.js
```

### Test with Example Workflow

Use the example workflows in `example-workflows.json`:

1. **Simple Sleep Notification**: Basic workflow for testing
2. **Oura Sleep Score Email**: Complete workflow with conditions

## Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**
   ```bash
   kubectl describe pod -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server
   kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server --previous
   ```

2. **API Authentication Errors**
   ```bash
   # Check if API key is set correctly
   kubectl get secret n8n-mcp-secret -n mcp-servers -o jsonpath='{.data.api-key}' | base64 -d
   ```

3. **Network Connectivity Issues**
   ```bash
   # Test n8n service from mcp-servers namespace
   kubectl run test-pod --rm -i --tty --image=curlimages/curl -n mcp-servers -- curl http://n8n.n8n.svc.cluster.local:5678/healthz
   ```

4. **npm Install Failures**
   ```bash
   # Check init container logs
   kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server -c npm-install
   ```

### Debug Commands

```bash
# Full pod description
kubectl describe pod -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server

# All container logs
kubectl logs -n mcp-servers -l app.kubernetes.io/name=n8n-mcp-server --all-containers=true

# Network policy check
kubectl describe networkpolicy n8n-mcp-server-netpol -n mcp-servers

# Service endpoints
kubectl get endpoints -n mcp-servers n8n-mcp-server
```

## Next Steps

1. ✅ Deploy the n8n MCP server
2. ✅ Verify connectivity to n8n
3. 🔄 Configure kagent to include n8n MCP server
4. 🔄 Test workflow creation through AI agents
5. 🔄 Create your first Oura sleep score workflow!

## Security Notes

- API keys are stored in Kubernetes secrets (encrypted at rest)
- Network access is restricted to n8n service only
- Container runs as non-root user (UID 1000)
- Resource limits prevent resource exhaustion attacks

## Support

- **Documentation**: See [n8n-mcp.md](../docs/n8n-mcp.md) for detailed docs
- **Examples**: Check `example-workflows.json` for workflow templates
- **Logs**: Use `kubectl logs` commands above for debugging
