# Terraform Module: Kubernetes Namespace Scaffolding
# Generates Kustomize manifests following fako-cluster patterns

terraform {
  required_version = ">= 1.0"
}

locals {
  base_path    = var.output_path != "" ? var.output_path : "${path.root}/../../apps/base/${var.app_name}"
  staging_path = var.output_path != "" ? "${var.output_path}/../staging/${var.app_name}" : "${path.root}/../../apps/staging/${var.app_name}"
}

# Namespace manifest
resource "local_file" "namespace" {
  filename = "${local.base_path}/namespace.yaml"
  content  = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.app_name}
  labels:
    app.kubernetes.io/name: ${var.app_name}
    app.kubernetes.io/part-of: ${local.part_of}
EOT
}

# Deployment manifest
resource "local_file" "deployment" {
  filename = "${local.base_path}/deployment.yaml"
  content  = templatefile("${path.module}/templates/deployment.yaml.tpl", {
    app_name           = var.app_name
    image              = local.image
    port               = var.port
    replicas           = var.replicas
    component          = var.component
    enable_secrets     = var.enable_secrets
    enable_storage     = var.enable_storage
    storage_mount_path = var.storage_mount_path
    resources          = var.resources
    health_check_path  = var.health_check_path
    env_vars           = var.env_vars
  })
}

# Service manifest
resource "local_file" "service" {
  filename = "${local.base_path}/service.yaml"
  content  = <<-EOT
apiVersion: v1
kind: Service
metadata:
  name: ${var.app_name}
  namespace: ${var.app_name}
  labels:
    app.kubernetes.io/name: ${var.app_name}
    app.kubernetes.io/component: ${var.component}
spec:
  type: ClusterIP
  ports:
    - port: ${var.port}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: ${var.app_name}
EOT
}

# Ingress manifest (optional)
resource "local_file" "ingress" {
  count    = var.enable_ingress ? 1 : 0
  filename = "${local.base_path}/ingress.yaml"
  content  = <<-EOT
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${var.app_name}
  namespace: ${var.app_name}
  labels:
    app.kubernetes.io/name: ${var.app_name}
    app.kubernetes.io/component: ${var.component}
  annotations:
    cert-manager.io/cluster-issuer: ${var.cluster_issuer}
spec:
  ingressClassName: ${var.ingress_class}
  tls:
    - hosts:
        - ${local.hostname}
      secretName: ${var.app_name}-tls
  rules:
    - host: ${local.hostname}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${var.app_name}
                port:
                  number: ${var.port}
EOT
}

# SecretStore manifest (optional)
resource "local_file" "secretstore" {
  count    = var.enable_secrets ? 1 : 0
  filename = "${local.base_path}/secretstore.yaml"
  content  = <<-EOT
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: ${var.app_name}
spec:
  provider:
    aws:
      auth:
        secretRef:
          accessKeyIDSecretRef:
            key: access-key-id
            name: aws-credentials
          secretAccessKeySecretRef:
            key: secret-access-key
            name: aws-credentials
      region: us-east-1
      service: SecretsManager
EOT
}

# ExternalSecret manifest (optional)
resource "local_file" "external_secret" {
  count    = var.enable_secrets ? 1 : 0
  filename = "${local.base_path}/external-secret.yaml"
  content  = templatefile("${path.module}/templates/external-secret.yaml.tpl", {
    app_name = var.app_name
    secrets  = var.secrets
  })
}

# DockerHub registry secret (optional)
resource "local_file" "external_secret_dockerhub" {
  count    = var.enable_secrets ? 1 : 0
  filename = "${local.base_path}/external-secret-dockerhub.yaml"
  content  = <<-EOT
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: dockerhub-registry
  namespace: ${var.app_name}
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: dockerhub-registry
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: "{{ .dockerconfig | toString }}"
  data:
    - secretKey: dockerconfig
      remoteRef:
        key: dockerhub/credentials
        property: dockerconfigjson
EOT
}

# Storage manifest (optional)
resource "local_file" "storage" {
  count    = var.enable_storage ? 1 : 0
  filename = "${local.base_path}/storage.yaml"
  content  = <<-EOT
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${var.app_name}-pvc
  namespace: ${var.app_name}
  labels:
    app.kubernetes.io/name: ${var.app_name}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${var.storage_class}
  resources:
    requests:
      storage: ${var.storage_size}
EOT
}

# Redis manifest (optional)
resource "local_file" "redis" {
  count    = var.enable_redis ? 1 : 0
  filename = "${local.base_path}/redis.yaml"
  content  = templatefile("${path.module}/templates/redis.yaml.tpl", {
    app_name = var.app_name
    part_of  = local.part_of
  })
}

# Base Kustomization
resource "local_file" "kustomization_base" {
  filename = "${local.base_path}/kustomization.yaml"
  content  = templatefile("${path.module}/templates/kustomization.yaml.tpl", {
    app_name       = var.app_name
    component      = var.component
    part_of        = local.part_of
    enable_ingress = var.enable_ingress
    enable_secrets = var.enable_secrets
    enable_storage = var.enable_storage
    enable_redis   = var.enable_redis
  })
}

# Staging Kustomization
resource "local_file" "kustomization_staging" {
  filename = "${local.staging_path}/kustomization.yaml"
  content  = <<-EOT
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/${var.app_name}
EOT
}
