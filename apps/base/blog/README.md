# Blog Documentation Site

This directory contains the Kubernetes deployment for a Hugo-based documentation blog that consolidates all documentation from the Fako cluster into a single, searchable website.

## Overview

The blog uses Hugo with the hugo-book theme to create a clean, navigable documentation site. It automatically gathers and organizes documentation from various services across the cluster.

## Features

- **Automatic Documentation Collection**: Init containers gather all markdown documentation from the repository
- **Organized Structure**: Documentation is categorized into:
  - Services - Documentation for each deployed service
  - Guides - How-to guides and tutorials
  - Architecture - System design documentation
  - Security - Security configurations and best practices
  - Operations - Operational procedures and runbooks
- **Search Functionality**: Built-in search across all documentation
- **Dark Mode Support**: Automatic theme switching based on browser preferences
- **Git Integration**: Links to edit documentation in GitHub
- **Automatic Sync**: CronJob syncs documentation from GitHub every 6 hours

## Components

### Deployment
- **Hugo Server**: Runs the Hugo static site generator in server mode
- **Init Containers**:
  - `setup-hugo-site`: Creates the Hugo site structure and installs the theme
  - `gather-docs`: Clones the repository and copies all documentation files

### Storage
- **PersistentVolumeClaim**: 5Gi storage for the Hugo site content
- **ConfigMaps**: 
  - `hugo-config`: Hugo configuration file
  - `docs-content`: Script for copying documentation

### Networking
- **Service**: ClusterIP service exposing port 80
- **Ingress**: HTTPS ingress at `blog.fako-cluster.local`

### Automation
- **CronJob**: Syncs documentation from GitHub every 6 hours

## Documentation Structure

```
content/
├── _index.md                    # Homepage
└── docs/
    ├── _index.md               # Documentation index
    ├── services/               # Service documentation
    │   ├── mcp-servers/        # MCP server docs
    │   ├── kubescape/          # Kubescape docs
    │   ├── kagent/             # Kagent docs
    │   ├── headlamp/           # Headlamp docs
    │   └── ...                 # Other services
    ├── guides/                 # How-to guides
    ├── architecture/           # Architecture docs
    ├── security/               # Security docs
    └── operations/             # Operations docs
```

## Usage

### Accessing the Blog

Once deployed, the documentation site will be available at:
```
https://blog.fako-cluster.local
```

### Adding New Documentation

1. **For existing services**: Place markdown files in the appropriate directory under `apps/base/[service-name]/`
2. **For new categories**: Update the init container scripts to include new documentation paths
3. **Commit to GitHub**: The CronJob will automatically sync new documentation

### Manual Sync

To manually trigger a documentation sync:
```bash
kubectl create job --from=cronjob/sync-docs manual-sync -n blog
```

### Viewing Logs

```bash
# Hugo server logs
kubectl logs -n blog deployment/hugo-blog

# Sync job logs
kubectl logs -n blog -l job-name=sync-docs-[job-id]
```

## Customization

### Theme Configuration

Edit the `configmap.yaml` to modify Hugo settings:
- Theme colors
- Menu items
- Search settings
- Repository links

### Content Organization

To reorganize content categories, modify:
1. The init container scripts in `deployment.yaml`
2. The sync script in `sync-docs-cronjob.yaml`
3. The copy script in `docs-content-configmap.yaml`

## Troubleshooting

### Blog Not Loading

1. Check pod status:
   ```bash
   kubectl get pods -n blog
   ```

2. Check init container logs:
   ```bash
   kubectl logs -n blog [pod-name] -c setup-hugo-site
   kubectl logs -n blog [pod-name] -c gather-docs
   ```

### Documentation Not Updating

1. Check CronJob status:
   ```bash
   kubectl get cronjobs -n blog
   ```

2. Check recent job runs:
   ```bash
   kubectl get jobs -n blog
   ```

### Storage Issues

1. Check PVC status:
   ```bash
   kubectl get pvc -n blog
   ```

2. Verify available storage:
   ```bash
   kubectl exec -n blog deployment/hugo-blog -- df -h /site
   ```

## Future Enhancements

- [ ] Add authentication for private documentation
- [ ] Implement versioning for documentation
- [ ] Add PDF export functionality
- [ ] Create automated documentation generation from code comments
- [ ] Add analytics to track popular documentation
