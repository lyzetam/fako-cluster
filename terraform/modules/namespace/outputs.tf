# Outputs for the namespace module

output "app_name" {
  description = "The application name"
  value       = var.app_name
}

output "namespace" {
  description = "The Kubernetes namespace name"
  value       = var.app_name
}

output "base_path" {
  description = "Path to the base manifests"
  value       = local.base_path
}

output "staging_path" {
  description = "Path to the staging manifests"
  value       = local.staging_path
}

output "hostname" {
  description = "The ingress hostname (if enabled)"
  value       = var.enable_ingress ? local.hostname : null
}

output "files_created" {
  description = "List of files created"
  value = compact([
    local_file.namespace.filename,
    local_file.deployment.filename,
    local_file.service.filename,
    var.enable_ingress ? local_file.ingress[0].filename : "",
    var.enable_secrets ? local_file.secretstore[0].filename : "",
    var.enable_secrets ? local_file.external_secret[0].filename : "",
    var.enable_secrets ? local_file.external_secret_dockerhub[0].filename : "",
    var.enable_storage ? local_file.storage[0].filename : "",
    var.enable_redis ? local_file.redis[0].filename : "",
    local_file.kustomization_base.filename,
    local_file.kustomization_staging.filename,
  ])
}

output "registration_entry" {
  description = "Entry to add to apps/staging/kustomization.yaml"
  value       = "  - ${var.app_name}"
}
