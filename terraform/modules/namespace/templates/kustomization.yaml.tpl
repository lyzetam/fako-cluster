apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${app_name}

resources:
  - namespace.yaml
%{ if enable_secrets ~}
  - secretstore.yaml
  - external-secret.yaml
  - external-secret-dockerhub.yaml
%{ endif ~}
%{ if enable_redis ~}
  - redis.yaml
%{ endif ~}
%{ if enable_storage ~}
  - storage.yaml
%{ endif ~}
  - deployment.yaml
  - service.yaml
%{ if enable_ingress ~}
  - ingress.yaml
%{ endif ~}

labels:
  - pairs:
      app.kubernetes.io/name: ${app_name}
      app.kubernetes.io/instance: production
      app.kubernetes.io/component: ${component}
      app.kubernetes.io/part-of: ${part_of}
