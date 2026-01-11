# Infrastructure as Code (IaC)

This directory contains Terraform configurations for AWS infrastructure. **These are NOT managed by Flux** and are kept separate from the Kubernetes manifests.

## Structure

```
iac/
├── aws-secrets/          # AWS Secrets Manager secrets for cluster
│   ├── provider.tf
│   └── secrets-manager.tf
└── README.md
```

## Important Notes

- **Separation of Concerns**: Terraform manages AWS infrastructure (secrets, IAM, etc.)
- **Kubernetes Manifests**: The `apps/` and `infrastructure/` directories contain only K8s YAML manifests managed by Flux
- **Not Git-Ignored**: `.tf` files ARE committed to Git, but state files and local overrides ARE ignored (see `.gitignore`)
- **Manual Deployment**: Changes to Terraform configs require manual `terraform apply`

## Setup

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured with credentials
- `aws-credentials-secret.yaml` properly decrypted in the cluster (for ExternalSecret sync)

### Deployment

```bash
cd iac/aws-secrets

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Secret Management Workflow

1. **Create Secret in AWS** (via Terraform)
   ```bash
   cd iac/aws-secrets
   terraform apply
   ```

2. **Sync to Kubernetes** (automatic via ExternalSecret)
   - `SecretStore` in K8s references AWS credentials
   - `ExternalSecret` syncs the AWS secret to K8s Secret
   - Lives in: `apps/base/alpaca-secrets/`

3. **Use in Pods**
   - Deployments reference the synced K8s Secret
   - No direct AWS API calls needed in pods

## Terraform State

State files are **not committed** to Git (see `.gitignore`). Store them safely:
- Local development: Store `.tfstate` locally (excluded from Git)
- Production: Consider using Terraform Cloud or S3 backend with encryption

## Adding New AWS Resources

1. Create a new Terraform module under `iac/<service>/`
2. Add `provider.tf` and resource files
3. Create corresponding `SecretStore` and `ExternalSecret` YAML in `apps/base/<service>/`
4. `terraform apply` to create AWS resources
5. Flux will automatically sync to K8s via ExternalSecret

## Troubleshooting

**ExternalSecret not syncing?**
```bash
# Check ExternalSecret status
kubectl get externalsecret -n <namespace>
kubectl describe externalsecret <name> -n <namespace>

# Verify SecretStore has AWS credentials
kubectl get secretstore -n <namespace>
```

**Terraform state conflicts?**
```bash
# Refresh state
terraform refresh

# View current state
terraform state show
```

## References
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [External Secrets Operator](https://external-secrets.io/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
