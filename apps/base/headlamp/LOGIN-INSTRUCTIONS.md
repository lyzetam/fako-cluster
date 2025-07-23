# Headlamp Login Instructions

## Access URL
https://headlamp.landryzetam.net

## Authentication
Headlamp requires authentication when accessed from a browser. A service account with appropriate permissions has been created for this purpose.

## Login Steps

1. Navigate to https://headlamp.landryzetam.net
2. You will be presented with a login screen
3. Select "Token" as the authentication method
4. Enter the authentication token (provided separately for security)

### Service Account Details
- **Service Account Name**: headlamp-admin
- **Namespace**: kube-system
- **Permissions**: cluster-admin (full admin access)

## Installing Kubescape Plugin

Once logged in:

1. Navigate to **Settings** → **Plugins**
2. Search for "kubescape" in the plugin catalog
3. Click **Install** on the Kubescape plugin
4. The plugin will add security dashboards to your Headlamp interface

## Features Available After Plugin Installation

- **Compliance Dashboard**: View NSA, MITRE, CIS framework compliance scores
- **Vulnerability Explorer**: Browse and filter container vulnerabilities
- **Network Policies**: Visualize generated network policies
- **RBAC Explorer**: View role bindings and permissions
- **Workload Security**: Per-workload security posture scores

## Troubleshooting

If you need to recreate the token:
```bash
# Delete old token
kubectl delete secret headlamp-admin-token -n kube-system

# Recreate by applying the service account config
kubectl apply -f apps/base/headlamp/admin-serviceaccount.yaml
```

## Security Note

The service account has cluster-admin privileges. For production use, consider creating service accounts with more restricted permissions based on the principle of least privilege.
