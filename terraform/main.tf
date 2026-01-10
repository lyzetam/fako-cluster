# Terraform configuration for fako-cluster namespace automation
#
# This file demonstrates how to use the namespace module to create
# multiple namespaces with different configurations.
#
# Usage:
#   cd terraform
#   terraform init
#   terraform plan
#   terraform apply
#

terraform {
  required_version = ">= 1.0"

  # Optional: Configure backend for state management
  # backend "s3" {
  #   bucket = "fako-terraform-state"
  #   key    = "namespaces/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Example: Simple web application
module "example_webapp" {
  source = "./modules/namespace"

  app_name       = "example-webapp"
  port           = 8080
  enable_ingress = true
  hostname       = "webapp.fako-cluster.local"
  component      = "frontend"
  part_of        = "example-platform"
}

# Example: API service with secrets
module "example_api" {
  source = "./modules/namespace"

  app_name       = "example-api"
  image          = "ghcr.io/lzetam/example-api:v1.0.0"
  port           = 3000
  enable_ingress = true
  enable_secrets = true
  hostname       = "api.fako-cluster.local"
  component      = "backend"
  part_of        = "example-platform"

  secrets = [
    {
      secret_key = "DATABASE_URL"
      remote_key = "example-api/database"
      property   = "url"
    },
    {
      secret_key = "API_KEY"
      remote_key = "example-api/credentials"
      property   = "api_key"
    }
  ]
}

# Example: Worker with storage and Redis
module "example_worker" {
  source = "./modules/namespace"

  app_name       = "example-worker"
  replicas       = 2
  enable_storage = true
  enable_redis   = true
  enable_secrets = true
  storage_size   = "50Gi"
  component      = "worker"
  part_of        = "example-platform"

  resources = {
    requests_memory = "512Mi"
    requests_cpu    = "200m"
    limits_memory   = "1Gi"
    limits_cpu      = "1000m"
  }
}

# Outputs
output "namespaces_created" {
  description = "List of namespaces created"
  value = {
    example_webapp = module.example_webapp.namespace
    example_api    = module.example_api.namespace
    example_worker = module.example_worker.namespace
  }
}

output "registration_entries" {
  description = "Entries to add to apps/staging/kustomization.yaml"
  value = [
    module.example_webapp.registration_entry,
    module.example_api.registration_entry,
    module.example_worker.registration_entry,
  ]
}
