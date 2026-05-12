# P2 NetworkPolicy Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish baseline default-deny NetworkPolicy in every active namespace, with explicit allow rules for required east-west and egress traffic. Currently ~11% of active namespaces (5 of 44) have any NetworkPolicy; a compromised pod in the other 39 can freely reach postgres, ollama, keycloak, the K8s API, and every other workload.

**Architecture:**
- Per-namespace policy = `default-deny-all` + 1+ explicit `allow-*` policies for legitimate traffic.
- Allow DNS to `kube-system` (UDP 53, TCP 53) is required in every default-deny namespace — pods cannot resolve hostnames otherwise.
- Allow ingress to monitoring/scrape namespaces (`monitoring` ns) for `/metrics` endpoints.
- Cluster CNI: K3s uses Flannel by default which does NOT enforce NetworkPolicy. **VERIFY the CNI supports NetworkPolicy before rolling out** — otherwise these policies are silent no-ops.

**Tech Stack:** Kubernetes NetworkPolicy v1.

---

## Pre-flight: Verify CNI supports NetworkPolicy

- [ ] **Step 1: Identify CNI**

```bash
kubectl get pods -n kube-system | grep -iE "flannel|calico|cilium|weave|kube-router"
```

- [ ] **Step 2: Decision tree**

| CNI | NetworkPolicy support | Action |
|---|---|---|
| Flannel (default K3s) | NO | This plan cannot proceed. First swap CNI to Calico (`--flannel-backend=none` + `kubectl apply` Calico) or add `kube-router` for policy enforcement. |
| Calico | YES | Proceed. |
| Cilium | YES | Proceed (consider CiliumNetworkPolicy for richer features). |
| kube-router | YES | Proceed. |

**If the cluster is on plain Flannel**, this plan converts to: "deploy a NetworkPolicy-enforcing CNI first." That is a separate, larger project — pause this plan and write that one.

---

## Task 1: Author canonical templates

**Files:**
- Create: `apps/base/_templates/networkpolicy-default-deny.yaml`
- Create: `apps/base/_templates/networkpolicy-allow-dns.yaml`
- Create: `apps/base/_templates/networkpolicy-allow-metrics-scrape.yaml`

- [ ] **Step 1: `apps/base/_templates/networkpolicy-default-deny.yaml`**

```yaml
# Drop into each namespace as the FIRST policy.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

- [ ] **Step 2: `apps/base/_templates/networkpolicy-allow-dns.yaml`**

```yaml
# REQUIRED in every default-deny namespace.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-to-kube-system
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
```

- [ ] **Step 3: `apps/base/_templates/networkpolicy-allow-metrics-scrape.yaml`**

```yaml
# Drop in namespaces whose pods expose /metrics for Prometheus.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-metrics-scrape-from-monitoring
spec:
  podSelector: {}  # or specific label selector for pods exposing metrics
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - { protocol: TCP, port: 9090 }  # adjust per app
```

- [ ] **Step 4: Commit templates**

```bash
git add apps/base/_templates/
git commit -m "feat(network): add NetworkPolicy templates (default-deny, allow-dns, allow-metrics)"
git push origin main
```

---

## Task 2: Roll out to tier-1 namespaces (highest-value targets)

Apply default-deny + allow-dns + necessary per-app rules to:

- [ ] `postgres-cluster` (allow ingress on 5432 from quantum-trades, zi, ai-news, paperless, langfuse, family-manager, n3xis, thornus, task-tracker, oura-*, donetick, etc.)
- [ ] `keycloak` (allow ingress on 8080 from oauth2-proxy in headlamp + any other consumer; allow egress to postgres)
- [ ] `headlamp` (allow ingress from traefik; allow egress to oauth2-proxy → auth.landryzetam.net; allow egress to kube API server)
- [ ] `ollama` (allow ingress from voice-pipeline-test, ollama-webui, open-webui, zi agents; allow egress to model registry HTTPS)
- [ ] `claude-code` (allow ingress on 22 from specific n8n source pods only)

**Per-namespace pattern (example: postgres-cluster):**

```yaml
# apps/base/postgres-cluster/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: postgres
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: postgres
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgres-ingress
  namespace: postgres
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: postgres-cluster
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  - quantum-trades
                  - zi
                  - ai-news
                  - paperless-ngx
                  - langfuse
                  - family-manager
                  - n3xis
                  - thornus
                  - task-tracker
                  - donetick
                  - oura-collector
                  - oura-agent
                  - keycloak
                  - umami
                  - sermon-engine
                  - meal-tracker
                  - n8n
                  - market-replay
                  - whisperx
                  - audio-workflows
                  - autobots
      ports:
        - { protocol: TCP, port: 5432 }
```

Add to `apps/base/postgres-cluster/kustomization.yaml` resources list.

**Per-namespace workflow:**

```bash
# Author the policy
# Validate
kustomize build apps/staging/postgres-cluster/ | kubectl apply --dry-run=server -f -
git add apps/base/postgres-cluster/networkpolicy.yaml apps/base/postgres-cluster/kustomization.yaml
# Reviewer
git commit -m "feat(network): default-deny + scoped postgres ingress allow"
git push origin main
flux reconcile kustomization apps
# Observe — anything broken?
kubectl get events -n postgres --field-selector type=Warning --since=10m
# If apps lose DB access: identify missing namespace in egress allowlist and add
```

---

## Task 3: Roll out to remaining active namespaces

For each of the remaining ~34 unpolicied namespaces, apply:
1. `default-deny-all`
2. `allow-dns-to-kube-system`
3. App-specific ingress allows (typically: from Traefik for HTTP-facing services)
4. App-specific egress allows (typically: to postgres, ollama, public HTTPS)

**Suggested order (least-coupled first to minimize blast radius):**

- [ ] static frontends: blog, lzt-ui, umami, autobots
- [ ] AI/voice stack: whisperx, whisper-cpu, piper, openwakeword, audio-workflows
- [ ] app pods: ai-news, donetick, paperless-ngx, langfuse, sermon-engine, meal-tracker, n3xis, ai-mastery-path
- [ ] data pods: quantum-trades, zi, market-replay, oura-collector, oura-agent, family-manager, thornus, task-tracker, phoenix
- [ ] infra-adjacent: gitleaks, kube-bench, kubescape-operator, housekeeping, n8n, sftp-server, mcp-gateway
- [ ] heavy use: open-webui, ollama-webui, exo

**Workflow per namespace:**

1. Identify ingress callers by reading the ingress + checking what calls the service (`kubectl get networkpolicy -A` + `kubectl logs` for service requests)
2. Identify egress targets from the deployment env vars (look for hostnames, DB connection strings)
3. Author the policy
4. Apply with `default-deny` first, observe for 1 hour
5. Add allows as breakages appear

---

## Task 4: Document the matrix

- [ ] Create `notes/docs/operations/networkpolicy-matrix.md`:

```markdown
# NetworkPolicy Matrix

| Namespace | Ingress allowed from | Egress allowed to |
|---|---|---|
| postgres | quantum-trades, zi, ai-news, ... (TCP 5432) | kube-system DNS, monitoring scrape |
| keycloak | headlamp, oura-dashboard, ... (TCP 8080) | kube-system DNS, postgres (5432) |
| ollama | voice-pipeline-test, zi, ... (TCP 11434) | kube-system DNS, registry (HTTPS) |
| ... | ... | ... |
```

This is the audit-time source of truth — keeps the policy intent traceable.

---

## Self-Review

- ✅ Pre-flight CNI check prevents silent no-op policies
- ✅ Templates created first; per-namespace policies inherit pattern
- ✅ Tier-1 (high-value) namespaces first
- ✅ Phased rollout per namespace (default-deny → observe → add allows)
- ⚠ Will likely cause transient breakage; require ~1 hour observation window per high-traffic namespace
