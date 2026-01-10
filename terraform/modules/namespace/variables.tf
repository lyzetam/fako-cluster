# Terraform Module: Kubernetes Namespace Scaffolding
# This module generates Kustomize manifests for fako-cluster namespaces

variable "app_name" {
  description = "Name of the application (used for namespace, labels, etc.)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.app_name)) || can(regex("^[a-z]$", var.app_name))
    error_message = "App name must be lowercase alphanumeric with dashes, starting with a letter."
  }
}

variable "image" {
  description = "Container image for the deployment"
  type        = string
  default     = ""
}

variable "port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 1
}

variable "component" {
  description = "Application component label"
  type        = string
  default     = "application"
}

variable "part_of" {
  description = "Part-of label for grouping"
  type        = string
  default     = ""
}

variable "enable_ingress" {
  description = "Enable ingress configuration"
  type        = bool
  default     = false
}

variable "hostname" {
  description = "Ingress hostname"
  type        = string
  default     = ""
}

variable "enable_secrets" {
  description = "Enable AWS Secrets Manager integration"
  type        = bool
  default     = false
}

variable "secrets" {
  description = "Map of secret key to AWS secret path/property"
  type = list(object({
    secret_key = string
    remote_key = string
    property   = string
  }))
  default = []
}

variable "enable_storage" {
  description = "Enable PersistentVolumeClaim"
  type        = bool
  default     = false
}

variable "storage_size" {
  description = "Storage size for PVC"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = "nfs-csi-v2"
}

variable "storage_mount_path" {
  description = "Mount path for storage volume"
  type        = string
  default     = "/data"
}

variable "enable_redis" {
  description = "Enable Redis deployment for caching"
  type        = bool
  default     = false
}

variable "resources" {
  description = "Resource requests and limits"
  type = object({
    requests_memory = string
    requests_cpu    = string
    limits_memory   = string
    limits_cpu      = string
  })
  default = {
    requests_memory = "256Mi"
    requests_cpu    = "100m"
    limits_memory   = "512Mi"
    limits_cpu      = "500m"
  }
}

variable "health_check_path" {
  description = "Path for health checks"
  type        = string
  default     = "/health"
}

variable "env_vars" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
}

variable "output_path" {
  description = "Path to output generated manifests"
  type        = string
  default     = ""
}

variable "cluster_issuer" {
  description = "Cert-manager cluster issuer for TLS"
  type        = string
  default     = "letsencrypt-staging"
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

# Computed locals
locals {
  image    = var.image != "" ? var.image : "ghcr.io/lzetam/${var.app_name}:latest"
  hostname = var.hostname != "" ? var.hostname : "${var.app_name}.fako-cluster.local"
  part_of  = var.part_of != "" ? var.part_of : var.app_name
}
