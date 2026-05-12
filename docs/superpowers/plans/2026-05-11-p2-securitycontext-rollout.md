# P2 SecurityContext Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `securityContext` to every Deployment/StatefulSet/CronJob in `apps/base/` so containers run as non-root with dropped capabilities and read-only root filesystem where possible. The 2026-05-11 audit found only ~10 of ~100 deployments set `readOnlyRootFilesystem: true`, and very few drop all capabilities. Also sets `automountServiceAccountToken: false` for pods that don't call the K8s API.

**Architecture:**
- One canonical securityContext template, applied with per-pod overrides when needed (e.g., specific UID/GID, retained capabilities).
- Phased: dry-run with `automountServiceAccountToken: false` only first (zero blast radius for pods that don't talk to K8s API), then non-root migrations, then `readOnlyRootFilesystem: true` last (highest breakage risk).
- This plan PRESUMES `2026-05-11-p1-podsecurity-baseline.md` is already in `warn` mode so we can spot violations early.

**Tech Stack:** Kubernetes Pod Security Contexts.

---

## Canonical Template

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: false  # set true ONLY if pod calls K8s API
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000          # or image-specific
        runAsGroup: 1000
        fsGroup: 1000            # only if pod has writable volumes
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            readOnlyRootFilesystem: true   # last phase
            capabilities:
              drop: ["ALL"]
```

**Per-pod overrides:**
- Postgres workloads: `runAsUser: 26`, `fsGroup: 26`
- Voice/audio: may need `fsGroup` for shared NFS PVC writes
- Sshd containers (claude-code): may need `NET_BIND_SERVICE` capability if binding port 22
- GPU workloads: tolerate as-is (handled by GPU operator)

---

## Task 1: `automountServiceAccountToken: false` everywhere appropriate

**Rationale:** Most pods don't call the K8s API. Auto-mounting the SA token is gratuitous attack surface — any RCE in the container immediately yields a token that can list/get resources in its namespace.

- [ ] **Step 1: Identify pods that DO call K8s API**

```bash
# Look for pods whose Deployment references a non-default ServiceAccount, or that mount kube-api-tied tools
grep -rln "serviceAccountName:" apps/base/ \
  | xargs grep -l "serviceAccountName:" \
  | xargs grep -L "serviceAccountName: default"
```

These need to KEEP automount on (or get a projected token explicitly).

- [ ] **Step 2: For everyone else, add to pod spec**

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: false
      # ... rest of spec
```

- [ ] **Step 3: Commit per app group (5-10 apps per commit)**

```bash
git add apps/base/<app1>/ apps/base/<app2>/ ...
git commit -m "chore(security): automountServiceAccountToken false on non-K8s-API pods

Pods that do not call the K8s API no longer mount a SA token by default.
Reduces blast radius of in-pod RCE.

P3 from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin main
```

---

## Task 2: Pod-level securityContext (runAsNonRoot, dropCaps)

Apply the canonical template (without `readOnlyRootFilesystem`) to all deployments. Pods that fail to start as non-root indicate the image expects root — those need image fix or runAsUser override.

**Workflow per app:**

- [ ] **Step 1: Read existing spec**

```bash
kubectl exec -n <ns> deploy/<name> -- id
# Expected: uid=0(root) → needs fix
# Expected: uid=1000(...) → already non-root, just add formal securityContext
```

- [ ] **Step 2: Edit deployment.yaml**

Add to pod spec:

```yaml
      securityContext:
        runAsNonRoot: true
        runAsUser: <appropriate-uid>
        runAsGroup: <appropriate-gid>
        seccompProfile:
          type: RuntimeDefault
```

Add to each container:

```yaml
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            capabilities:
              drop: ["ALL"]
```

- [ ] **Step 3: Validate, commit, push, observe**

```bash
kustomize build apps/staging/<app>/ | kubectl apply --dry-run=server -f -
git add apps/base/<app>/
git commit -m "chore(<app>): runAsNonRoot + drop ALL caps"
git push origin main
flux reconcile kustomization apps
kubectl rollout status deployment/<name> -n <ns>
# If rollout fails, check logs for "permission denied" or "operation not permitted"
# Common fix: image-specific runAsUser; or chown the volume mount via initContainer
```

**Apps to do (group by ~5 per commit, ~20 commits total):**

Stateless frontends (lowest risk): blog, lzt-ui, autobots, umami, ai-mastery-path, sermon-engine, donetick, paperless-ngx, n3xis

App backends: ai-news, autobots, family-manager, thornus, task-tracker, phoenix, market-replay, quantum-trades (9 services)

ML/voice: ollama, ollama-webui, open-webui, whisperx, whisper-cpu, piper, openwakeword, audio-workflows

Data: oura-collector, oura-agent, oura-dashboard, meal-tracker, zi, mcp-servers, paperless-ngx, langfuse

Tools/infra: n8n, mcp-gateway, sftp-server, housekeeping (cronjob), kube-bench-reporter, kubescape-reporter

Special handling: postgres-cluster (UID 26), keycloak (UID 1000), claude-code (NET_BIND_SERVICE), kube-bench (privileged retained)

---

## Task 3: `readOnlyRootFilesystem: true` (highest breakage risk)

Many apps write to `/tmp`, `/var/log`, or other directories at runtime. For each container that fails after this change:
- Identify writable paths (`kubectl exec <pod> -- mount | grep "(rw"`)
- Add an `emptyDir` volume mount for that path

**Workflow:**

- [ ] **Step 1: Set the flag and observe**

For each container:

```yaml
          securityContext:
            readOnlyRootFilesystem: true
```

- [ ] **Step 2: Run for 24h, monitor for crashes**

```bash
kubectl get events -A --field-selector reason=BackOff --since=24h
```

- [ ] **Step 3: For crashing pods, identify writable paths**

```bash
kubectl logs <pod> --previous | grep -iE "read-only|permission denied|cannot create"
```

Common locations needing emptyDir:
- `/tmp`
- `/var/cache`
- `/var/run`
- `/var/lib/<app>`
- `/.config`
- `/home/<user>`

- [ ] **Step 4: Add tmpfs volumes**

```yaml
        volumeMounts:
          - { name: tmp, mountPath: /tmp }
          - { name: cache, mountPath: /var/cache }
      volumes:
        - { name: tmp, emptyDir: { medium: Memory, sizeLimit: 64Mi } }
        - { name: cache, emptyDir: {} }
```

- [ ] **Step 5: Re-deploy and verify**

```bash
kubectl rollout restart deployment/<name> -n <ns>
kubectl rollout status deployment/<name> -n <ns>
```

---

## Task 4: Special cases — kube-bench, GPU workloads, sshd

**kube-bench:** Already documented as accepted-risk (CIS scanner needs hostPID + privileged). Keep as-is but confirm it's not network-reachable.

**GPU workloads (aitower):** Some Ollama/Whisper images may need fsGroup for shared model cache PVCs. Don't drop NVIDIA's runtime additions.

**claude-code:** Tested in P0 plan. If sshd needs port 22, retain `NET_BIND_SERVICE`.

**audio-workflows / Argo controllers:** May need `serviceAccountName: argo` and automount=true to manage workflows.

---

## Self-Review

- ✅ Phased rollout (token first → user/caps second → root FS third) minimizes breakage
- ✅ Per-pod override pattern documented
- ✅ Validation step after each commit
- ⚠ readOnlyRootFilesystem will cause real breakage for some apps; the 24h observation window catches it
- ⚠ Should be sequenced AFTER `2026-05-11-p1-podsecurity-baseline.md` reaches `warn` mode so violations are visible
