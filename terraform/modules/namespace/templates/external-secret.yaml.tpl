apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${app_name}-secrets
  namespace: ${app_name}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: ${app_name}-secrets
    creationPolicy: Owner
  data:
%{ if length(secrets) > 0 ~}
%{ for secret in secrets ~}
    - secretKey: ${secret.secret_key}
      remoteRef:
        key: ${secret.remote_key}
%{ if secret.property != "" ~}
        property: ${secret.property}
%{ endif ~}
%{ endfor ~}
%{ else ~}
    # Add your secrets here
    # Example:
    # - secretKey: API_KEY
    #   remoteRef:
    #     key: ${app_name}/api-key
    #     property: key
    - secretKey: PLACEHOLDER
      remoteRef:
        key: ${app_name}/config
        property: placeholder
%{ endif ~}
