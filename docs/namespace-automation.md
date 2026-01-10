# Namespace Automation Guide

This guide describes the available methods for automating Kubernetes namespace creation in the fako-cluster GitOps repository.

## Overview

Creating a new application namespace in fako-cluster involves generating several Kubernetes manifests following established patterns:

- **Namespace**: The Kubernetes namespace resource
- **Deployment**: Application workload definition
- **Service**: Internal service exposure
- **Ingress** (optional): External access via ingress controller
- **SecretStore/ExternalSecret** (optional): AWS Secrets Manager integration
- **PersistentVolumeClaim** (optional): Persistent storage
- **Redis** (optional): Caching layer
- **Kustomization**: Resource aggregation for Kustomize

Three automation approaches are available:

| Approach | Best For | Complexity | Self-Service |
|----------|----------|------------|--------------|
| Shell Script | CLI users, quick scaffolding | Low | No |
| Terraform | IaC teams, bulk creation | Medium | No |
| Backstage | Developer portal, self-service | High | Yes |

## Approach 1: Shell Script

The `create-namespace.sh` script provides quick CLI-based namespace scaffolding.

### Installation

```bash
# The script is already available in the repository
chmod +x automation/create-namespace.sh
```

### Usage

```bash
# Basic usage - creates minimal namespace
./automation/create-namespace.sh my-app

# Full-featured application
./automation/create-namespace.sh my-api \
  --with-ingress \
  --with-secrets \
  --with-storage \
  --storage-size 50Gi \
  --image ghcr.io/myorg/my-api:v1.0.0 \
  --port 3000 \
  --host api.example.com \
  --register

# Preview changes without creating files
./automation/create-namespace.sh my-app --dry-run
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--with-ingress` | Include ingress configuration | false |
| `--with-secrets` | Include AWS Secrets Manager integration | false |
| `--with-storage` | Include PersistentVolumeClaim | false |
| `--with-redis` | Include Redis deployment | false |
| `--image <image>` | Container image | ghcr.io/lzetam/<app>:latest |
| `--port <port>` | Container port | 8080 |
| `--host <hostname>` | Ingress hostname | <app>.fako-cluster.local |
| `--component <comp>` | Component label | application |
| `--part-of <group>` | Part-of label | <app-name> |
| `--storage-size <size>` | Storage size | 10Gi |
| `--replicas <n>` | Number of replicas | 1 |
| `--register` | Auto-register in staging | false |
| `--dry-run` | Preview without writing | false |

### Generated Structure

```
apps/
├── base/<app-name>/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml          # if --with-ingress
│   ├── secretstore.yaml      # if --with-secrets
│   ├── external-secret.yaml  # if --with-secrets
│   ├── storage.yaml          # if --with-storage
│   ├── redis.yaml            # if --with-redis
│   └── kustomization.yaml
└── staging/<app-name>/
    └── kustomization.yaml
```

---

## Approach 2: Terraform Module

The Terraform module provides infrastructure-as-code namespace management, ideal for teams already using Terraform or needing bulk namespace creation.

### Prerequisites

```bash
# Install Terraform (if not already installed)
brew install terraform  # macOS
# or
curl -fsSL https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip -o terraform.zip
unzip terraform.zip && sudo mv terraform /usr/local/bin/
```

### Usage

1. **Navigate to Terraform directory**:
```bash
cd terraform
```

2. **Initialize Terraform**:
```bash
terraform init
```

3. **Edit `main.tf`** to define your namespaces:
```hcl
module "my_api" {
  source = "./modules/namespace"

  app_name       = "my-api"
  image          = "ghcr.io/myorg/my-api:v1.0.0"
  port           = 3000
  enable_ingress = true
  enable_secrets = true
  hostname       = "api.example.com"
  component      = "backend"
  part_of        = "my-platform"

  secrets = [
    {
      secret_key = "DATABASE_URL"
      remote_key = "my-api/database"
      property   = "url"
    },
    {
      secret_key = "API_KEY"
      remote_key = "my-api/credentials"
      property   = "api_key"
    }
  ]

  resources = {
    requests_memory = "512Mi"
    requests_cpu    = "200m"
    limits_memory   = "1Gi"
    limits_cpu      = "1000m"
  }
}
```

4. **Preview changes**:
```bash
terraform plan
```

5. **Apply changes**:
```bash
terraform apply
```

6. **Register in staging** (manual step):
```bash
# Add to apps/staging/kustomization.yaml
echo "  - my-api" >> ../apps/staging/kustomization.yaml
```

### Module Variables

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `app_name` | string | Application name (required) | - |
| `image` | string | Container image | ghcr.io/lzetam/<app>:latest |
| `port` | number | Container port | 8080 |
| `replicas` | number | Pod replicas | 1 |
| `component` | string | Component label | application |
| `part_of` | string | Part-of label | <app_name> |
| `enable_ingress` | bool | Enable ingress | false |
| `hostname` | string | Ingress hostname | <app>.fako-cluster.local |
| `enable_secrets` | bool | Enable secrets | false |
| `secrets` | list | Secret mappings | [] |
| `enable_storage` | bool | Enable PVC | false |
| `storage_size` | string | PVC size | 10Gi |
| `storage_class` | string | Storage class | nfs-csi-v2 |
| `enable_redis` | bool | Enable Redis | false |
| `resources` | object | Resource limits | (see defaults) |
| `health_check_path` | string | Health check path | /health |
| `env_vars` | map | Environment variables | {} |

### Bulk Creation Example

```hcl
# Create multiple namespaces at once
locals {
  apps = {
    "api-gateway" = {
      port           = 8080
      enable_ingress = true
      component      = "gateway"
    }
    "user-service" = {
      port           = 3000
      enable_secrets = true
      component      = "backend"
    }
    "notification-worker" = {
      port         = 8080
      enable_redis = true
      component    = "worker"
    }
  }
}

module "apps" {
  for_each = local.apps
  source   = "./modules/namespace"

  app_name       = each.key
  port           = each.value.port
  enable_ingress = lookup(each.value, "enable_ingress", false)
  enable_secrets = lookup(each.value, "enable_secrets", false)
  enable_redis   = lookup(each.value, "enable_redis", false)
  component      = each.value.component
  part_of        = "my-platform"
}
```

---

## Approach 3: Backstage Software Template

The Backstage template provides a self-service developer portal experience with a guided UI for namespace creation.

### Prerequisites

- Backstage instance deployed and configured
- GitHub integration for PR creation
- Template catalog registered

### Setup

1. **Register the template** in your Backstage catalog:
```yaml
# catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: fako-templates
spec:
  type: url
  targets:
    - https://github.com/lzetam/fako-cluster/blob/main/backstage/templates/namespace-template/template.yaml
```

2. **Configure GitHub integration** in Backstage for PR creation.

### Usage

1. Navigate to **Create** in Backstage
2. Select **Fako Cluster Namespace** template
3. Fill in the wizard:
   - Application name
   - Container image and port
   - Feature toggles (ingress, secrets, storage, redis)
   - Resource preset
4. Review and create
5. A Pull Request is automatically created

### Template Parameters

**Application Details**:
- `appName`: Unique application name
- `description`: Short description
- `owner`: Owning team/user

**Container Configuration**:
- `image`: Docker image
- `port`: Container port
- `replicas`: Number of replicas

**Features**:
- `enableIngress`: External access
- `hostname`: Ingress hostname
- `enableSecrets`: AWS Secrets Manager
- `enableStorage`: Persistent storage
- `storageSize`: PVC size
- `enableRedis`: Redis cache

**Resource Configuration**:
- `component`: Component type
- `partOf`: Parent platform
- `resourcePreset`: tiny/small/medium/large

---

## Post-Creation Steps

After generating namespace manifests (regardless of approach):

### 1. Review Generated Files

```bash
# Validate manifests
kubectl kustomize apps/base/<app-name>
kubectl kustomize apps/staging/<app-name>
```

### 2. Configure Secrets (if enabled)

Edit `apps/base/<app-name>/external-secret.yaml` with your actual AWS secret paths:

```yaml
spec:
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: my-app/database
        property: url
    - secretKey: API_KEY
      remoteRef:
        key: my-app/credentials
        property: api_key
```

Create the corresponding secrets in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name my-app/database \
  --secret-string '{"url": "postgres://..."}'
```

### 3. Register Application

Add the app to `apps/staging/kustomization.yaml`:

```yaml
resources:
  # ... existing apps ...
  - my-app  # Add your new app
```

### 4. Commit and Push

```bash
git add apps/base/<app-name> apps/staging/<app-name>
git add apps/staging/kustomization.yaml
git commit -m "feat: add <app-name> namespace"
git push
```

### 5. Monitor Deployment

FluxCD will automatically detect and deploy the changes:

```bash
# Check Flux reconciliation
flux get kustomizations

# Watch the deployment
kubectl get pods -n <app-name> -w
```

---

## Customization

### Adding Custom Labels

Edit the `kustomization.yaml` to add custom labels:

```yaml
labels:
  - pairs:
      app.kubernetes.io/name: my-app
      team: platform
      cost-center: engineering
```

### Adding Resource Quotas

Create `resource-quota.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: my-app
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
```

### Adding Network Policies

Create `network-policy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: my-app
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

---

## Comparison Matrix

| Feature | Shell Script | Terraform | Backstage |
|---------|-------------|-----------|-----------|
| CLI-based | Yes | Yes | No |
| UI-based | No | No | Yes |
| State management | No | Yes | No |
| Bulk creation | Manual | Yes | No |
| Self-service | No | No | Yes |
| PR workflow | No | No | Yes |
| Validation | Basic | HCL | Schema |
| Learning curve | Low | Medium | Medium |
| Prerequisites | Bash | Terraform | Backstage |

## Troubleshooting

### Script Permission Denied

```bash
chmod +x automation/create-namespace.sh
```

### Terraform State Issues

```bash
# Reinitialize if modules change
terraform init -upgrade
```

### Backstage Template Not Found

Ensure the template is registered in your catalog:

```bash
# Check template status
curl http://backstage:7007/api/catalog/entities?filter=kind=template
```

### FluxCD Not Deploying

```bash
# Force reconciliation
flux reconcile kustomization apps --with-source

# Check for errors
flux get kustomizations
kubectl describe kustomization apps -n flux-system
```
