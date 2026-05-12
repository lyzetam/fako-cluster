# P1 PodSecurity Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply Kubernetes PodSecurity Standards (PSS) namespace labels to all 64 namespaces missing them, so newly-created pods are rejected if they violate the chosen baseline. Currently only 2 of 66 namespaces have PSS labels (fieldy-webhook = restricted, pixie = privileged).

**Architecture:**
- 3 enforcement modes per namespace: `restricted` (default), `baseline` (cluster infra, GPU workloads), `privileged` (kube-bench, kubescape, GPU device plugin).
- Phased rollout: `warn` + `audit` first (no enforcement), let logs surface violations, then flip to `enforce`.
- This is preventive — does not retroactively block running pods. New pods or pod restarts that fail PSS are blocked.

**Tech Stack:** Kubernetes Pod Security Admission (in-tree, GA since 1.25).

---

## File Structure

**Files modified:** every `apps/base/<app>/namespace.yaml` (≈40 files), plus infrastructure namespaces.

**Files created:** `notes/docs/operations/podsecurity-classification.md` — classification rationale per namespace.

---

## Classification

| Mode | Namespaces |
|---|---|
| **restricted** (default, strictest) | fieldy-webhook ✅, ai-mastery-path, ai-news, autobots, blog, claude-code, donetick, lzt-ui, market-replay, meal-tracker, n3xis, oura-collector, oura-agent, oura-dashboard, paperless-ngx, phoenix, quantum-trades, task-tracker, thornus, umami, wger, zeroed, zi, family-manager, n8n, sftp-server, mcp-servers (excluding bridge), backstage, langfuse, headlamp |
| **baseline** | postgres-cluster (UID 26 needs fsGroup), pgadmin, keycloak, ollama, ollama-webui, open-webui, oura-dashboard if it needs streamlit fs writes, mcp-servers/filesystem-mcp-bridge if NET_BIND, audio-workflows (Argo controller may need wider scope), whisperx, whisper-cpu, piper, piper-v13, openwakeword, ollama-jetson, ollama-jetson2, exo, sermon-engine, voice-pipeline-test, gitleaks, kubescape-operator, gpustack-proxy |
| **privileged** | kube-bench (hostPID, privileged), kubescape-operator if needed, pixie ✅, voice-ingest if SELinux relabel needed, mcp-gateway (verify), node-labeling |

**Verification command per namespace** (to confirm classification before flipping enforce):

```bash
kubectl get events -n <namespace> --field-selector reason=FailedCreate,type=Warning | grep -i "violates PodSecurity"
```

---

## Task 1: Add `warn` + `audit` to all namespaces (non-breaking)

For each namespace.yaml, add PSS labels but ONLY in `warn` and `audit` mode. This causes the API server to log violations without rejecting pods.

**Canonical pattern (restricted mode, warn-only):**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <app-name>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/part-of: <part>
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

**Baseline mode warn-only:**

```yaml
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/audit: baseline
```

**Privileged (effectively no warning):**

```yaml
    pod-security.kubernetes.io/warn: privileged
    pod-security.kubernetes.io/audit: privileged
```

- [ ] **Step 1: Group namespaces by intended mode**

Use the classification table above. Create `notes/docs/operations/podsecurity-classification.md` with the rationale.

- [ ] **Step 2: Edit each namespace.yaml**

For each row in the classification, edit `apps/base/<name>/namespace.yaml` and add the appropriate `warn` + `audit` labels.

- [ ] **Step 3: Validate**

```bash
for f in $(find apps/base -name namespace.yaml); do
  yq '.metadata.labels' "$f" | grep -q "pod-security" || echo "MISSING: $f"
done
# Expected: empty output
```

- [ ] **Step 4: One commit per mode group**

```bash
git add apps/base/<group-1>/namespace.yaml apps/base/<group-2>/namespace.yaml ...
git commit -m "chore(security): add PodSecurity restricted warn/audit labels (group 1)

Non-enforcing. API server will log violations for review.

P1 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin main
flux reconcile kustomization apps
```

Repeat for baseline and privileged groups.

---

## Task 2: Observe violations for 1 week

- [ ] **Step 1: Set a calendar reminder for 2026-05-18**

Use `/schedule` or set a calendar event.

- [ ] **Step 2: Collect audit events**

```bash
# Audit events appear in the apiserver audit log (location depends on K3s config)
# OR via warnings in deploy events:
kubectl get events -A --field-selector reason=PodSecurityWarning -o wide
```

- [ ] **Step 3: For each namespace with violations**

Either:
- Fix the pod spec (preferred — add securityContext per `2026-05-11-p2-securitycontext-rollout.md`)
- Downgrade the namespace's intended mode (e.g., restricted → baseline)

---

## Task 3: Flip `enforce` on namespaces with zero violations

- [ ] **Step 1: Identify clean namespaces**

After 1 week of observation, list namespaces with no PodSecurityWarning events.

- [ ] **Step 2: Add `enforce` label**

For each clean namespace, add:

```yaml
    pod-security.kubernetes.io/enforce: <restricted|baseline|privileged>
```

(matching the `warn`/`audit` mode already in place)

- [ ] **Step 3: Commit per namespace group**

```bash
git commit -m "chore(security): enforce PodSecurity on <group>

Observation window 2026-05-11 → 2026-05-18 showed no violations.

P1 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Lock in default for new namespaces

Add a Kyverno or in-cluster admission policy that defaults all new namespaces to PSS `baseline` if no label is set.

**Optional — Kyverno policy** (if Kyverno is installed):

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: namespace-pss-default
spec:
  validationFailureAction: Audit
  rules:
    - name: require-pss-label
      match:
        any:
          - resources:
              kinds: ["Namespace"]
      validate:
        message: "Namespace must declare pod-security.kubernetes.io/enforce"
        pattern:
          metadata:
            labels:
              "pod-security.kubernetes.io/enforce": "?*"
```

- [ ] Verify if Kyverno is installed: `kubectl get crd | grep kyverno`
- [ ] If yes, add the policy. If no, defer to a later plan (deploying Kyverno is its own project).

---

## Self-Review

- ✅ All namespaces classified
- ✅ Phased rollout (warn → audit → enforce) avoids surprise pod rejections
- ✅ Observation window documented
- ⚠ Some classifications are guesses; Task 2 surfaces real violations and lets us re-classify
