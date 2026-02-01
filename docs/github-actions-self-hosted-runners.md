# GitHub Actions Self-Hosted Runners Proposal

**Status:** Proposed
**Date:** 2026-01-27
**Author:** Claude Code

## Overview

Replace GitHub-hosted runners with self-hosted runners on the K3s cluster to eliminate GitHub Actions billing costs.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub.com                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Private Repo│    │ Private Repo│    │ Public Repo │         │
│  │   (safe)    │    │   (safe)    │    │  (DO NOT)   │         │
│  └──────┬──────┘    └──────┬──────┘    └─────────────┘         │
│         └──────────────────┼───────────────────────────         │
│                            ▼                                     │
│                   ┌─────────────────┐                           │
│                   │   Job Queue     │                           │
│                   └────────┬────────┘                           │
└────────────────────────────┼────────────────────────────────────┘
                             │ HTTPS (outbound only)
                             ▼
┌────────────────────────────────────────────────────────────────┐
│                    fako-cluster (K3s)                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Actions Runner Controller (ARC)              │  │
│  │         Namespace: arc-system                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Runner Pods (Ephemeral)                      │  │
│  │         Namespace: arc-runners                            │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │  │
│  │  │ Runner  │  │ Runner  │  │ Runner  │  │ Runner  │     │  │
│  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │  │  Pod N  │     │  │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

## Security Considerations

### Critical: Public vs Private Repos

| Repo Visibility | Self-Hosted Runners | Reason |
|-----------------|---------------------|--------|
| **Private** | ✅ Safe | Only collaborators can trigger workflows |
| **Public** | ❌ DO NOT USE | Anyone can fork, modify workflow, run arbitrary code on your cluster |

**Risk with public repos:** An attacker forks your public repo, modifies `.github/workflows/` to run `kubectl delete ns --all` or crypto miners, opens a PR, and the workflow executes on your cluster.

### Repos in Scope

Review each repo before enabling self-hosted runners:

| Repo | Visibility | Self-Hosted? | Notes |
|------|------------|--------------|-------|
| `fako-cluster` | Public | ❌ NO | Infrastructure repo - keep using GitHub-hosted |
| `quantum-trades` | ? | Check first | Only if private |
| `phoenix` | ? | Check first | Only if private |
| `hugo` | ? | Check first | Only if private |
| `family-manager-bot` | ? | Check first | Only if private |

**Action required:** Run `gh repo list --visibility public` to identify all public repos.

### Security Measures Included

1. **Ephemeral runners** - Pod destroyed after each job, no credential leakage
2. **Resource limits** - CPU: 2 cores, Memory: 4Gi max per runner
3. **Namespace isolation** - Runners in dedicated `arc-runners` namespace
4. **Minimal PAT scope** - Fine-grained token with only required permissions
5. **Secret rotation** - ExternalSecrets refreshes GitHub token hourly
6. **No privileged containers** - DinD runs in rootless mode where possible

### GitHub Token Permissions (Minimal)

Fine-grained PAT with repository-specific access:

| Permission | Access | Purpose |
|------------|--------|---------|
| `actions` | Read/Write | Register runners, receive jobs |
| `administration` | Read/Write | Manage runner registration |
| `metadata` | Read | Required for API access |

**Do NOT use classic PAT with broad `repo` scope.**

---

## Implementation Plan

### Directory Structure

```
fako-cluster/
├── infrastructure/
│   ├── controllers/
│   │   ├── base/
│   │   │   └── actions-runner-controller/
│   │   │       ├── kustomization.yaml
│   │   │       ├── namespace.yaml
│   │   │       ├── repository.yaml
│   │   │       └── release.yaml
│   │   └── staging/
│   │       └── actions-runner-controller/
│   │           └── kustomization.yaml
│   │
│   └── configs/
│       ├── base/
│       │   └── arc-runners/
│       │       ├── kustomization.yaml
│       │       ├── namespace.yaml
│       │       ├── secret-store.yaml
│       │       ├── external-secret.yaml
│       │       └── runner-<repo-name>.yaml  # One per private repo
│       └── staging/
│           └── arc-runners/
│               └── kustomization.yaml
```

### Phase 1: Prerequisites

1. **Audit repo visibility**
   ```bash
   gh repo list lyzetam --visibility public --json name
   gh repo list lyzetam --visibility private --json name
   ```

2. **Create GitHub PAT**
   - Go to: GitHub → Settings → Developer settings → Fine-grained tokens
   - Token name: `fako-cluster-arc`
   - Expiration: 90 days (set calendar reminder to rotate)
   - Repository access: Select only private repos that need runners
   - Permissions: `actions:rw`, `administration:rw`, `metadata:read`

3. **Store token in AWS Secrets Manager**
   ```bash
   aws secretsmanager create-secret \
     --name github/actions-runner-token \
     --secret-string '{"github_token":"ghp_xxxx"}'
   ```

### Phase 2: Deploy ARC Controller

**`infrastructure/controllers/base/actions-runner-controller/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: arc-system
```

**`infrastructure/controllers/base/actions-runner-controller/repository.yaml`**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: actions-runner-controller
  namespace: arc-system
spec:
  interval: 24h
  url: oci://ghcr.io/actions/actions-runner-controller-charts
  type: oci
```

**`infrastructure/controllers/base/actions-runner-controller/release.yaml`**
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: arc-controller
  namespace: arc-system
spec:
  interval: 30m
  timeout: 10m
  chart:
    spec:
      chart: gha-runner-scale-set-controller
      version: "0.9.x"
      sourceRef:
        kind: HelmRepository
        name: actions-runner-controller
        namespace: arc-system
  install:
    crds: CreateReplace
  upgrade:
    crds: CreateReplace
  values:
    replicaCount: 1
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

**`infrastructure/controllers/base/actions-runner-controller/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: arc-system
resources:
  - namespace.yaml
  - repository.yaml
  - release.yaml
```

### Phase 3: Deploy Runner Configuration

**`infrastructure/configs/base/arc-runners/namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: arc-runners
```

**`infrastructure/configs/base/arc-runners/secret-store.yaml`**
```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: arc-runners
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
```

**`infrastructure/configs/base/arc-runners/external-secret.yaml`**
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: github-token
  namespace: arc-runners
spec:
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: github-token
    creationPolicy: Owner
  data:
    - secretKey: github_token
      remoteRef:
        key: github/actions-runner-token
        property: github_token
  refreshInterval: 1h
```

**`infrastructure/configs/base/arc-runners/runner-template.yaml`** (copy per repo)
```yaml
# Copy this file as runner-<repo-name>.yaml for each PRIVATE repo
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: arc-runner-REPO_NAME
  namespace: arc-runners
spec:
  interval: 30m
  chart:
    spec:
      chart: gha-runner-scale-set
      version: "0.9.x"
      sourceRef:
        kind: HelmRepository
        name: actions-runner-controller
        namespace: arc-system
  values:
    githubConfigUrl: "https://github.com/lyzetam/REPO_NAME"
    githubConfigSecret:
      github_token:
        secretRef:
          name: github-token
          key: github_token
    minRunners: 0        # Scale to zero when idle
    maxRunners: 3        # Max concurrent jobs
    runnerScaleSetName: "k8s-REPO_NAME"
    containerMode:
      type: "dind"       # Docker-in-Docker for image builds
    template:
      spec:
        containers:
          - name: runner
            image: ghcr.io/actions/actions-runner:latest
            resources:
              limits:
                cpu: "2"
                memory: "4Gi"
              requests:
                cpu: "500m"
                memory: "1Gi"
```

**`infrastructure/configs/base/arc-runners/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: arc-runners
resources:
  - namespace.yaml
  - secret-store.yaml
  - external-secret.yaml
  # Add runner files for each PRIVATE repo:
  # - runner-quantum-trades.yaml
  # - runner-phoenix.yaml
```

### Phase 4: Update Staging Overlays

**`infrastructure/controllers/staging/actions-runner-controller/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: arc-system
resources:
  - ../../base/actions-runner-controller/
```

**`infrastructure/configs/staging/arc-runners/kustomization.yaml`**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: arc-runners
resources:
  - ../../base/arc-runners/
```

### Phase 5: Update Flux Kustomizations

Add to `infrastructure/controllers/staging/kustomization.yaml`:
```yaml
resources:
  - external-secrets/
  - cert-manager/
  - actions-runner-controller/  # ADD
  # ... other controllers
```

Add to `infrastructure/configs/staging/kustomization.yaml`:
```yaml
resources:
  - cert-manager/
  - nfs-config/
  - arc-runners/  # ADD
  # ... other configs
```

### Phase 6: Update App Workflows

For each **private** repo using self-hosted runners, update `.github/workflows/*.yml`:

```yaml
# Before
jobs:
  build:
    runs-on: ubuntu-latest

# After
jobs:
  build:
    runs-on: [self-hosted, k8s-REPO_NAME]  # Matches runnerScaleSetName
```

---

## Verification Checklist

| Step | Command | Expected |
|------|---------|----------|
| ARC controller running | `kubectl get pods -n arc-system` | 1/1 Running |
| Runner pods exist | `kubectl get pods -n arc-runners` | Pods present (or 0 if scaled down) |
| Runners registered | GitHub → Repo → Settings → Actions → Runners | Shows self-hosted runners |
| ExternalSecret synced | `kubectl get externalsecret -n arc-runners` | SecretSynced |
| Test workflow | Push to private repo | Job runs on self-hosted |

---

## Cost Analysis

| Scenario | GitHub Hosted | Self-Hosted |
|----------|---------------|-------------|
| 100 builds/month @ 10 min | ~$8/month | $0 |
| 500 builds/month @ 10 min | ~$40/month | $0 |
| 2000 builds/month @ 10 min | ~$160/month | $0 |

Self-hosted uses existing cluster resources. Only additional cost is runner pod CPU/memory consumption.

---

## Maintenance

### Token Rotation (Every 90 Days)

1. Create new PAT in GitHub
2. Update AWS Secrets Manager:
   ```bash
   aws secretsmanager put-secret-value \
     --secret-id github/actions-runner-token \
     --secret-string '{"github_token":"ghp_NEW_TOKEN"}'
   ```
3. ExternalSecrets auto-refreshes within 1 hour

### Scaling Adjustments

Edit runner HelmRelease values:
- `minRunners: 0` - Scale to zero when idle (cost-efficient)
- `minRunners: 1` - Always keep one warm (faster job start)
- `maxRunners: N` - Limit concurrent jobs

### Troubleshooting

```bash
# Check ARC controller logs
kubectl logs -n arc-system -l app.kubernetes.io/name=gha-runner-scale-set-controller

# Check runner pod logs
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner

# Check if runners are registered
kubectl get runners -n arc-runners

# Force reconciliation
flux reconcile kustomization infrastructure-configs --with-source
```

---

## Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| GitHub-hosted runners | Zero maintenance | Billing costs | Current state |
| Self-hosted on K3s (ARC) | No billing, GitOps native | Security for public repos | **Selected for private repos** |
| Jenkins | Full control | High maintenance, not GitOps | Rejected |
| Standalone runner on VM | Simple setup | No auto-scaling, manual management | Rejected |
| FluxCD Image Automation | Already using Flux | Only handles image updates | Complementary |

---

## References

- [GitHub Actions Runner Controller](https://github.com/actions/actions-runner-controller)
- [ARC Helm Charts](https://github.com/actions/actions-runner-controller/tree/master/charts)
- [Self-hosted runner security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
- [Fine-grained PAT permissions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
