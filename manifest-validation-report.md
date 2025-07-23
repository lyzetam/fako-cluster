# Manifest Validation Report
Generated: 2025-01-23

## Summary

### Namespaces Found in Cluster
Total: 41 namespaces

### Analysis Categories

## 1. Applications Deployed (from apps/staging)
These applications are defined in staging and confirmed deployed:

| Application | Namespace | Status |
|-------------|-----------|--------|
| audiobookshelf | audiobookshelf | ✅ Deployed |
| gitleaks | security-scanning | ✅ Deployed (CronJob active) |
| gpustack-proxy | gpustack-proxy | ✅ Deployed |
| headlamp | headlamp | ✅ Deployed |
| kagent | kagent | ✅ Deployed |
| keycloak | keycloak | ✅ Deployed |
| kube-bench | kube-bench | ✅ Deployed |
| kubescape-operator | kubescape | ✅ Deployed |
| linkding | linkding | ✅ Deployed |
| mcp-servers | mcp-servers | ✅ Deployed |
| n8n | n8n | ✅ Deployed |
| node-labeling | node-labeling | ✅ Deployed |
| ollama | ollama | ✅ Deployed |
| ollama-webui | ollama-webui | ✅ Deployed |
| openwakeword | openwakeword | ✅ Deployed |
| oura-collector | oura-collector | ✅ Deployed |
| oura-dashboard | oura-dashboard | ✅ Deployed |
| pgadmin | pgadmin | ✅ Deployed |
| piper | piper | ✅ Deployed |
| postgres-cluster | postgres | ✅ Deployed |
| wger | wger | ✅ Deployed |
| whisper | whisper | ✅ Deployed |

## 2. Unused Application Manifests (to be removed)
These exist in apps/base but are NOT deployed:

| Application | Path | Reason |
|-------------|------|--------|
| homebot | apps/base/homebot | Commented out in staging |
| voice-monitor | apps/base/voice-monitor | Not in staging |

## 3. Infrastructure/Monitoring Namespaces
These are managed by infrastructure/monitoring directories:

| Namespace | Type | Source |
|-----------|------|--------|
| alloy | Monitoring | monitoring/controllers/base/alloy |
| backup-system | Infrastructure | infrastructure/controllers/base/k8s-backup |
| cert-manager | Infrastructure | infrastructure/controllers/base/cert-manager |
| cnpg-system | Infrastructure | infrastructure/controllers/base/cloudnative-pg |
| external-secrets-system | Infrastructure | infrastructure/controllers/base/external-secrets |
| flux-system | Infrastructure | Flux bootstrap |
| gpu-monitoring | Monitoring | monitoring/controllers/base/gpu-monitoring |
| gpu-operator | Infrastructure | infrastructure/controllers/base/gpu-operator |
| loki-stack | Monitoring | monitoring/controllers/base/loki-stack |
| monitoring | Monitoring | monitoring/controllers/base/kube-prometheus-stack |
| nfs-system | Infrastructure | infrastructure/controllers/base/nfs-storage |
| renovate | Infrastructure | infrastructure/controllers/base/renovate |
| system-tuning | Infrastructure | infrastructure/controllers/base/system-tuning |

## 4. Unknown/Orphaned Namespaces
These namespaces exist but have no clear manifest source:

| Namespace | Notes | Resources Found |
|-----------|-------|-----------------|
| cluster-diagnostics | No manifest found | Only kube-root-ca.crt (auto-created) |
| infrastructure | No manifest found | aws-credentials secret, nfs-config secret, kube-root-ca.crt |

## 5. System Namespaces (Do not remove)
- default
- kube-node-lease
- kube-public
- kube-system

## Actions Completed

### ✅ Removed these directories:
1. `apps/base/homebot/` - Not deployed, commented out
2. `apps/staging/homebot/` - Removed staging overlay
3. `apps/base/voice-monitor/` - Not deployed, not in staging
4. `apps/staging/voice-monitor/` - No staging overlay existed

### ⚠️ Namespaces to Investigate:
1. `cluster-diagnostics` namespace - Only contains auto-generated kube-root-ca.crt, safe to delete
2. `infrastructure` namespace - Contains aws-credentials and nfs-config secrets, verify if still needed

## Cleanup Summary

All unused manifest directories have been removed. The GitOps repository now only contains manifests for actively deployed applications. The two orphaned namespaces (`cluster-diagnostics` and `infrastructure`) appear to be leftovers:
- `cluster-diagnostics` can likely be deleted as it only contains the auto-generated certificate
- `infrastructure` namespace should be investigated as it contains secrets that might be in use
