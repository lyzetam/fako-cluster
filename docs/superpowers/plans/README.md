# Platform Security Remediation Plans — 2026-05-11

Plans derived from the `/platform-security` audit performed 2026-05-11.

| Plan | Scope | Active impact | Status |
|---|---|---|---|
| [P0 RBAC & Runtime Hardening](2026-05-11-p0-rbac-and-runtime-hardening.md) | Headlamp cluster-admin removal + oauth2-proxy; kubernetes-mcp RBAC; filesystem-mcp-bridge hardening; claude-code | YES (headlamp, claude-code) | Executing |
| [P1 Image Pinning](2026-05-11-p1-image-pinning.md) | Pin all `:latest` tags (~80 references); gpu-operator HelmRelease | Low (mechanical) | Queued |
| [P1 PodSecurity Baseline](2026-05-11-p1-podsecurity-baseline.md) | PSS namespace labels (warn → audit → enforce) | Low (observation phase first) | Queued |
| [P2 NetworkPolicy Rollout](2026-05-11-p2-networkpolicies.md) | default-deny per namespace; allow rules for legitimate east-west | High (transient breakage) — depends on NetworkPolicy-enforcing CNI | Queued, blocked on CNI verification |
| [P2 SecurityContext Rollout](2026-05-11-p2-securitycontext-rollout.md) | runAsNonRoot, drop caps, readOnlyRootFilesystem on all deployments | Medium (rOFS may break some apps) | Queued, depends on PSS warn mode being on |

## Execution order recommendation

1. **P0 first** — biggest single risk reduction (headlamp public exposure, dormant MCP RBAC).
2. **P1 image pinning** — mechanical, low risk, unblocks Renovate CVE tracking.
3. **P1 PSS baseline (warn/audit)** — non-enforcing, surfaces violations.
4. **P2 securityContext** — relies on PSS warn mode to confirm pods comply.
5. **P2 NetworkPolicies** — only after CNI swap confirmed (Flannel default doesn't enforce).
