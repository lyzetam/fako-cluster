# P0 RBAC & Runtime Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the 4 CRITICAL findings from the 2026-05-11 platform-security audit: headlamp `cluster-admin` exposure, headlamp ClusterRole wildcard, `kubernetes-mcp-server` cluster-wide secrets write, `filesystem-mcp-bridge` root + NET_ADMIN + dynamic-kubectl-download anti-pattern. Also adds securityContext to `claude-code`.

**Architecture:**
- For **active** components (headlamp, claude-code): change RBAC and add oauth2-proxy fronting using the existing oura-dashboard pattern (oauth2-proxy → Keycloak `master` realm → AWS Secrets Manager for client creds).
- For **dormant** components (mcp-servers — commented out in `apps/staging/kustomization.yaml`): tighten Git definitions so they're safe whenever re-enabled. Zero runtime risk during this work.
- Per-fix commits. Each commit gates on a `code-reviewer` + `security-reviewer` subagent pass before push. fako-cluster main is protected; we DO NOT skip hooks.

**Tech Stack:** Kubernetes RBAC, FluxCD, Kustomize, ExternalSecrets (AWS provider), oauth2-proxy, Keycloak.

---

## File Structure

**Files modified:**
- `apps/base/headlamp/admin-serviceaccount.yaml` — strip `cluster-admin`, bind to scoped role
- `apps/base/headlamp/rbac.yaml` — drop wildcard verbs, allow read-only + namespace-scoped exec/log
- `apps/base/headlamp/ingress.yaml` — switch backend to `oauth2-proxy:4180`
- `apps/base/headlamp/kustomization.yaml` — add new oauth2-proxy resources
- `apps/base/mcp-servers/kubernetes-mcp/rbac.yaml` — drop cluster-wide write on secrets; pods/exec scoped via RoleBinding (cluster-binding kept read-only)
- `apps/base/mcp-servers/filesystem-mcp/bridge-deployment.yaml` — replace inline kubectl-download with pinned `bitnami/kubectl:1.32.3` image co-deployed; pod-level non-root; drop NET_ADMIN; readOnlyRootFilesystem
- `apps/base/claude-code/deployment.yaml` — add pod & container securityContext (runAsNonRoot, drop caps, allowPrivilegeEscalation false); pin image tag

**Files created:**
- `apps/base/headlamp/oauth2-proxy-deployment.yaml`
- `apps/base/headlamp/oauth2-proxy-service.yaml`
- `apps/base/headlamp/secret-store.yaml`
- `apps/base/headlamp/external-secret-oauth2.yaml`
- `apps/base/headlamp/external-secret-aws.yaml` (or reuse existing pattern — see Task 6)
- `apps/base/mcp-servers/kubernetes-mcp/rbac-mcp-namespace.yaml` (new RoleBinding scoped to `mcp-servers` ns for pods/exec)
- `docs/operations/headlamp-keycloak-client.md` — manual Keycloak client setup runbook

**Out of scope (separate plans):**
- Image pinning across all `:latest` tags → `2026-05-11-p1-image-pinning.md`
- PSS namespace labels → `2026-05-11-p1-podsecurity-baseline.md`
- NetworkPolicies → `2026-05-11-p2-networkpolicies.md`
- SecurityContext rollout to all 100+ deployments → `2026-05-11-p2-securitycontext-rollout.md`

---

## Validation Convention (all tasks)

For every YAML change in `apps/base/<app>/`:

```bash
# 1. Kustomize build must succeed
kustomize build apps/staging/<app>/ > /tmp/build.yaml

# 2. Dry-run apply against the real cluster
kubectl apply --dry-run=server -f /tmp/build.yaml
```

For deployments: after merging and Flux reconciles, confirm the pod becomes Ready and probes pass.

---

## Task 1: Manual prerequisite — create Keycloak `headlamp` client and AWS secret

**This is a manual step the user performs ONCE before Task 6. It is not automatable here because Keycloak is not operator-managed.**

**Files:**
- Create: `docs/operations/headlamp-keycloak-client.md`

- [ ] **Step 1: Write the runbook**

Write `docs/operations/headlamp-keycloak-client.md` with content:

````markdown
# Headlamp Keycloak Client Setup

One-time manual step to wire oauth2-proxy in front of `headlamp.landryzetam.net`.

## 1. Create the Keycloak client

In Keycloak admin UI at `https://auth.landryzetam.net/` → `master` realm → Clients → Create:

| Field | Value |
|---|---|
| Client ID | `headlamp` |
| Client type | OpenID Connect |
| Client authentication | ON |
| Authorization | OFF |
| Standard flow | ON (Authorization Code) |
| Direct access grants | OFF |
| Root URL | `https://headlamp.landryzetam.net` |
| Valid redirect URIs | `https://headlamp.landryzetam.net/oauth2/callback` |
| Web origins | `https://headlamp.landryzetam.net` |

After saving, go to the Credentials tab and copy the client secret.

## 2. Generate a cookie secret

```bash
# 32-byte URL-safe base64
python3 -c 'import os, base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

## 3. Store in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "headlamp/oauth2-proxy" \
  --secret-string "$(cat <<EOF
{
  "client-id": "headlamp",
  "client-secret": "<paste-from-keycloak>",
  "cookie-secret": "<paste-from-step-2>"
}
EOF
)"
```

(If it already exists, use `put-secret-value` instead — see `~/.claude/projects/-Users-zz-dev-fako-cluster/memory/MEMORY.md`.)

## 4. Verify

```bash
aws secretsmanager get-secret-value --secret-id headlamp/oauth2-proxy --query SecretString --output text | jq
```

You should see all three keys non-empty. Now Task 6 can proceed.
````

- [ ] **Step 2: Commit the runbook**

```bash
git add docs/operations/headlamp-keycloak-client.md
git commit -m "$(cat <<'EOF'
docs(headlamp): add Keycloak client + AWS secret setup runbook

Prereq for fronting headlamp.landryzetam.net with oauth2-proxy.
Manual because Keycloak is not operator-managed in this cluster.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: User executes the runbook**

After the runbook is committed, the user creates the Keycloak client and the AWS secret. Do NOT proceed to Task 6 until verified:

```bash
aws secretsmanager get-secret-value --secret-id headlamp/oauth2-proxy --query SecretString --output text | jq 'has("client-id") and has("client-secret") and has("cookie-secret")'
# expected: true
```

---

## Task 2: Restrict `headlamp` ClusterRole to read-only

**Risk:** This is the SA the pod uses for the "default" view (no admin token). After this change, the unauthenticated/no-token headlamp view can only read state, not mutate. Users who need write actions paste the admin token (whose scope is reduced in Task 3) OR use kubectl.

**Files:**
- Modify: `apps/base/headlamp/rbac.yaml`

- [ ] **Step 1: Replace the entire ClusterRole**

Replace `apps/base/headlamp/rbac.yaml` content:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp
  namespace: headlamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: headlamp
rules:
# Read-only across all standard resources
- apiGroups: [""]
  resources:
    - pods
    - services
    - endpoints
    - persistentvolumeclaims
    - persistentvolumes
    - configmaps
    - namespaces
    - nodes
    - events
    - serviceaccounts
    - replicationcontrollers
    - resourcequotas
    - limitranges
  verbs: ["get", "list", "watch"]
# Logs (read-only — only "get" is valid on subresources)
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
# Pod status, metrics
- apiGroups: [""]
  resources:
    - pods/status
    - services/status
    - namespaces/status
  verbs: ["get"]
# Apps
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets", "controllerrevisions"]
  verbs: ["get", "list", "watch"]
# Batch
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
# Networking
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies", "ingressclasses"]
  verbs: ["get", "list", "watch"]
# Storage
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "volumeattachments", "csidrivers", "csinodes"]
  verbs: ["get", "list", "watch"]
# RBAC (read-only — viewing roles is fine; mutation requires admin token)
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
# Policy
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "list", "watch"]
# Autoscaling
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]
# API registration / admission (read-only)
- apiGroups: ["apiregistration.k8s.io"]
  resources: ["apiservices"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
  verbs: ["get", "list", "watch"]
# Metrics
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
# Kubescape CRDs (read-only)
- apiGroups: ["spdx.softwarecomposition.kubescape.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["core.kubescape.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: headlamp
subjects:
- kind: ServiceAccount
  name: headlamp
  namespace: headlamp
```

- [ ] **Step 2: Validate kustomize build**

```bash
kustomize build apps/staging/headlamp/ > /tmp/headlamp-build.yaml
grep -E "verbs:|name: headlamp$" /tmp/headlamp-build.yaml | head -40
```

Expected: no `verbs: ["*"]` anywhere in the headlamp ClusterRole.

- [ ] **Step 3: Dry-run server apply**

```bash
kubectl apply --dry-run=server -f /tmp/headlamp-build.yaml
```

Expected: `clusterrole.rbac.authorization.k8s.io/headlamp configured (server dry run)`. No errors.

- [ ] **Step 4: Stage and run code-reviewer + security-reviewer**

```bash
git add apps/base/headlamp/rbac.yaml
git diff --staged
```

Then dispatch reviewer subagents (see "Per-commit review workflow" at end of plan).

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
fix(headlamp): restrict ClusterRole to read-only verbs

Drops wildcard verbs across 14 API groups. The pod's ServiceAccount now
has get/list/watch only. Write/delete operations from the dashboard
require pasting the headlamp-admin token (whose scope is also reduced
in the following commit).

P0 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and verify Flux reconcile**

```bash
git push origin main
flux reconcile kustomization apps --with-source
kubectl get clusterrole headlamp -o yaml | yq '.rules[] | .verbs' | sort -u
# expected: only "get", "list", "watch" (and maybe a few read-only verbs); no "*"
```

---

## Task 3: Strip `cluster-admin` from `headlamp-admin`

**Risk:** After this, the admin token no longer grants cluster-admin. It binds to TWO scoped roles:
1. `headlamp` (the same read-only role used by the pod SA from Task 2) — reads everything **except secrets** (secrets are not in Task 2's resource list, by design).
2. `headlamp-admin` — write-only on workloads/config/ingress/HPA, NO write on RBAC/secrets/CRDs.

Net effect: the legacy admin token can browse the cluster (without secrets), modify workloads/config in any namespace, but cannot read secrets, modify RBAC, or modify CRDs. Users who paste this token into headlamp lose the ability to (a) view secret values via UI, (b) modify ClusterRoles. That's the point.

**Files:**
- Modify: `apps/base/headlamp/admin-serviceaccount.yaml`

- [ ] **Step 1: Replace the entire file**

Replace `apps/base/headlamp/admin-serviceaccount.yaml` content:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp-admin
  namespace: kube-system
  labels:
    app.kubernetes.io/name: headlamp-admin
    app.kubernetes.io/part-of: headlamp
---
# Write-only role for headlamp-admin SA. Reads come from the `headlamp`
# ClusterRole (Task 2) via the additional ClusterRoleBinding below.
# Reads explicitly EXCLUDE secrets (Task 2's resource list omits them).
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: headlamp-admin
  labels:
    app.kubernetes.io/name: headlamp-admin
    app.kubernetes.io/part-of: headlamp
rules:
# Workload writes
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets", "replicasets"]
  verbs: ["create", "update", "patch", "delete", "deletecollection"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["create", "update", "patch", "delete", "deletecollection"]
# Core resource writes (no secrets, no serviceaccounts, no namespaces)
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims", "events"]
  verbs: ["create", "update", "patch", "delete", "deletecollection"]
# Exec/portforward (subresources — only "create" is valid)
- apiGroups: [""]
  resources: ["pods/exec", "pods/portforward"]
  verbs: ["create"]
# Networking writes
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["create", "update", "patch", "delete"]
# Autoscaling writes
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["create", "update", "patch", "delete"]
---
# Binding 1: grants reads via the `headlamp` ClusterRole (defined in Task 2).
# This SA inherits the same secret-less read scope as the dashboard pod.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admin-read
  labels:
    app.kubernetes.io/name: headlamp-admin
    app.kubernetes.io/part-of: headlamp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: headlamp
subjects:
- kind: ServiceAccount
  name: headlamp-admin
  namespace: kube-system
---
# Binding 2: grants writes via the `headlamp-admin` ClusterRole defined above.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admin
  labels:
    app.kubernetes.io/name: headlamp-admin
    app.kubernetes.io/part-of: headlamp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: headlamp-admin
subjects:
- kind: ServiceAccount
  name: headlamp-admin
  namespace: kube-system
---
# Long-lived token kept for backward compatibility with current UI login.
# After oauth2-proxy is fronting (Task 6), consider rotating + deleting this.
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-admin-token
  namespace: kube-system
  labels:
    app.kubernetes.io/name: headlamp-admin
    app.kubernetes.io/part-of: headlamp
  annotations:
    kubernetes.io/service-account.name: headlamp-admin
type: kubernetes.io/service-account-token
```

- [ ] **Step 2: Validate**

```bash
kustomize build apps/staging/headlamp/ | grep -A2 "name: headlamp-admin$" | head -30
kustomize build apps/staging/headlamp/ | kubectl apply --dry-run=server -f -
```

- [ ] **Step 3: Stage, review, commit, push**

```bash
git add apps/base/headlamp/admin-serviceaccount.yaml
# Dispatch reviewers, fix blockers, then:
git commit -m "$(cat <<'EOF'
fix(headlamp): replace cluster-admin binding with scoped admin role

The headlamp-admin ServiceAccount no longer has cluster-admin. It now
binds to a new headlamp-admin ClusterRole: full read everywhere,
write on workloads/config/ingress/HPA, NO write on secrets, RBAC,
CRDs, or kube-system-only resources.

After this, the legacy admin token will not work for RBAC edits or
secret writes from the dashboard. Use kubectl for those.

P0 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
flux reconcile kustomization apps
```

- [ ] **Step 4: Verify on cluster**

```bash
# Should be denied — RBAC writes
kubectl auth can-i create clusterroles --as=system:serviceaccount:kube-system:headlamp-admin
# expected: no
# Should be denied — secret reads (the key blast-radius reduction)
kubectl auth can-i list secrets --as=system:serviceaccount:kube-system:headlamp-admin -A
# expected: no
kubectl auth can-i get secrets --as=system:serviceaccount:kube-system:headlamp-admin -n default
# expected: no
# Should be denied — secret writes
kubectl auth can-i create secrets --as=system:serviceaccount:kube-system:headlamp-admin -n default
# expected: no
# Should be allowed — normal workload reads/writes
kubectl auth can-i list pods --as=system:serviceaccount:kube-system:headlamp-admin -A
# expected: yes
kubectl auth can-i create deployments --as=system:serviceaccount:kube-system:headlamp-admin -n default
# expected: yes
```

---

## Task 4: Tighten `kubernetes-mcp-server` ClusterRole (dormant — Git-only fix)

**Context:** `mcp-servers` is commented out in `apps/staging/kustomization.yaml`. This change is preventive — locks down the RBAC before re-enable. No runtime impact today.

**Files:**
- Modify: `apps/base/mcp-servers/kubernetes-mcp/rbac.yaml`

- [ ] **Step 1: Replace ClusterRole with read-only; move write to namespace-scoped Role**

Replace `apps/base/mcp-servers/kubernetes-mcp/rbac.yaml` content:

```yaml
# Cluster-wide: read-only everywhere. The MCP server discovers and inspects
# resources cluster-wide but MUST NOT write outside its own namespace.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kubernetes-mcp-server
  labels:
    app.kubernetes.io/name: kubernetes-mcp-server
    app.kubernetes.io/component: mcp-server
    app.kubernetes.io/part-of: kagent
rules:
- apiGroups: [""]
  resources:
    - pods
    - services
    - endpoints
    - persistentvolumeclaims
    - configmaps
    - namespaces
    - nodes
    - events
    - pods/log
    - pods/status
    - services/status
    - namespaces/status
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-mcp-server
  labels:
    app.kubernetes.io/name: kubernetes-mcp-server
    app.kubernetes.io/component: mcp-server
    app.kubernetes.io/part-of: kagent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubernetes-mcp-server
subjects:
- kind: ServiceAccount
  name: kubernetes-mcp-server
  namespace: mcp-servers
---
# Write access ONLY within the mcp-servers namespace.
# Includes pods/exec (used by the bridge), workload/config writes, NOT secrets.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: kubernetes-mcp-server-writer
  namespace: mcp-servers
  labels:
    app.kubernetes.io/name: kubernetes-mcp-server
    app.kubernetes.io/component: mcp-server
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/portforward"]
  verbs: ["create"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kubernetes-mcp-server-writer
  namespace: mcp-servers
  labels:
    app.kubernetes.io/name: kubernetes-mcp-server
    app.kubernetes.io/component: mcp-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-mcp-server-writer
subjects:
- kind: ServiceAccount
  name: kubernetes-mcp-server
  namespace: mcp-servers
```

Notes vs. previous version:
- **Removed**: cluster-wide `create/update/patch` on `secrets` (was line 24-30 of original — full cluster takeover risk)
- **Removed**: cluster-wide `pods/exec` (was line 32-37) — moved to namespace-scoped Role
- **Removed**: cluster-wide write on deployments/statefulsets/jobs/ingresses/networkpolicies — moved to namespace-scoped Role
- Read paths kept cluster-wide so the MCP server can still discover state for kagent

- [ ] **Step 2: Validate** (mcp-servers is not in staging — build directly)

```bash
kustomize build apps/base/mcp-servers/ > /tmp/mcp-build.yaml
grep -c 'verbs: \["create' /tmp/mcp-build.yaml
# expected: present only inside Role kubernetes-mcp-server-writer, not in ClusterRole
```

Manual scan:

```bash
yq 'select(.kind == "ClusterRole" and .metadata.name == "kubernetes-mcp-server") | .rules[].verbs' /tmp/mcp-build.yaml | sort -u
# expected: only get/list/watch
```

- [ ] **Step 3: Stage, review, commit, push**

```bash
git add apps/base/mcp-servers/kubernetes-mcp/rbac.yaml
# Dispatch reviewers, fix blockers, then:
git commit -m "$(cat <<'EOF'
fix(mcp-servers): scope kubernetes-mcp RBAC; drop cluster-wide secret writes

ClusterRole becomes read-only across cluster. All write paths
(pods/exec, workload create/update/delete) moved to a namespace-scoped
Role bound only in mcp-servers. No cluster-wide secret writes.

mcp-servers is currently commented out in apps/staging/kustomization.yaml;
this is a preventive fix before re-enable.

P0 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 5: Replace `filesystem-mcp-bridge` runtime (dormant — Git-only fix)

**Files:**
- Modify: `apps/base/mcp-servers/filesystem-mcp/bridge-deployment.yaml`

The current bridge:
- Runs as root (UID 0)
- Adds `NET_ADMIN` capability
- `allowPrivilegeEscalation: true`
- Downloads kubectl over HTTP at startup
- Installs npm packages at startup
- Has hand-rolled inline JS server

For a P0 fix without rewriting the bridge logic, we:
1. Move the inline bridge JS into a ConfigMap (immutable, scanned, no `apk add`/`npm install` at startup)
2. Co-deploy `bitnami/kubectl:1.32.3` as a sidecar so the main container doesn't need to install kubectl
3. Pin `node:22.11-alpine`
4. Drop NET_ADMIN; runAsNonRoot; readOnlyRootFilesystem; allowPrivilegeEscalation false

Because the bridge invokes `kubectl exec` against another pod, and a true rewrite is out of scope, the **minimum viable hardening** is:
- Pinned image versions
- Non-root
- Drop ALL caps, NET_ADMIN removed
- readOnlyRootFilesystem with emptyDir for the writable paths

- [ ] **Step 1: Replace `apps/base/mcp-servers/filesystem-mcp/bridge-deployment.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filesystem-mcp-bridge-script
  namespace: mcp-servers
data:
  server.js: |
    const express = require('express');
    const WebSocket = require('ws');
    const http = require('http');
    const { spawn, exec } = require('child_process');

    const app = express();
    const server = http.createServer(app);
    const wss = new WebSocket.Server({ server });
    app.use(express.json());

    app.get('/health', (req, res) => {
      res.json({
        status: 'healthy',
        service: 'filesystem-mcp-bridge',
        timestamp: new Date().toISOString()
      });
    });

    app.get('/test', (req, res) => {
      const testCmd = 'kubectl exec -n mcp-servers deployment/filesystem-mcp-server -c mcp-filesystem-server -- ps aux | grep "node.*index.js"';
      exec(testCmd, (error, stdout) => {
        if (error) return res.status(500).json({ status: 'error', error: error.message });
        res.json({ status: 'connected', process: stdout.trim() });
      });
    });

    app.post('/mcp', (req, res) => {
      // Pipe the JSON body to `tee` via stdin — no shell, no interpolation.
      // The previous `sh -c "echo '${mcpRequest}' > /tmp/mcp_stdin"` form was
      // a command-injection sink: a single-quote in the body broke out of the
      // sh argument and ran arbitrary commands inside the MCP server pod.
      const mcpRequest = JSON.stringify(req.body);
      const proc = spawn('kubectl', [
        'exec', '-i', '-n', 'mcp-servers',
        'deployment/filesystem-mcp-server',
        '-c', 'mcp-filesystem-server',
        '--', 'tee', '/tmp/mcp_stdin'
      ], { stdio: ['pipe', 'ignore', 'pipe'] });
      let errorData = '';
      const t = setTimeout(() => {
        proc.kill();
        res.status(504).json({ jsonrpc: '2.0', error: { code: -32000, message: 'MCP timeout' }, id: req.body.id || null });
      }, 5000);
      proc.stderr.on('data', d => { errorData += d.toString(); });
      proc.on('close', code => {
        clearTimeout(t);
        if (code !== 0) {
          return res.status(500).json({ jsonrpc: '2.0', error: { code: -32000, message: 'MCP error', data: errorData }, id: req.body.id || null });
        }
        res.json({ jsonrpc: '2.0', result: { protocolVersion: '1.0.0', capabilities: {}, serverInfo: { name: 'filesystem-mcp', version: '1.0.0' } }, id: req.body.id || null });
      });
      proc.on('error', (err) => {
        clearTimeout(t);
        res.status(500).json({ jsonrpc: '2.0', error: { code: -32000, message: 'MCP spawn failed', data: err.message }, id: req.body.id || null });
      });
      proc.stdin.end(mcpRequest);
    });

    const PORT = 8080;
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`Filesystem MCP HTTP Bridge listening on ${PORT}`);
    });
  package.json: |
    {
      "name": "mcp-bridge",
      "version": "1.0.0",
      "main": "server.js",
      "dependencies": {
        "express": "4.21.2",
        "ws": "8.18.0"
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filesystem-mcp-bridge
  namespace: mcp-servers
  labels:
    app.kubernetes.io/name: filesystem-mcp-bridge
    app.kubernetes.io/component: mcp-bridge
    app.kubernetes.io/part-of: mcp-servers
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: filesystem-mcp-bridge
      app.kubernetes.io/component: mcp-bridge
  template:
    metadata:
      labels:
        app.kubernetes.io/name: filesystem-mcp-bridge
        app.kubernetes.io/component: mcp-bridge
    spec:
      serviceAccountName: filesystem-mcp-bridge
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      # Init containers run in the order listed. `prep` copies kubectl into
      # an emptyDir; `install-deps` populates node_modules in the bridge's
      # working emptyDir BEFORE the main container starts.
      initContainers:
        - name: prep
          image: bitnami/kubectl:1.32.3
          command: ["sh", "-c"]
          args:
            - |
              set -e
              cp /opt/bitnami/kubectl/bin/kubectl /kubectl/kubectl
              chmod +x /kubectl/kubectl
              cp /config/package.json /work/
          volumeMounts:
            - { name: kubectl-bin, mountPath: /kubectl }
            - { name: bridge-work, mountPath: /work }
            - { name: bridge-script, mountPath: /config }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities: { drop: ["ALL"] }
        - name: install-deps
          image: node:22.11-alpine
          command: ["sh", "-c"]
          args:
            - |
              set -e
              cd /work
              # --ignore-scripts: postinstall scripts can write outside /work
              # and would otherwise fail under readOnlyRootFilesystem on
              # the main container; deps used here (express, ws) don't need them.
              npm install --omit=dev --no-audit --no-fund --ignore-scripts
          volumeMounts:
            - { name: bridge-work, mountPath: /work }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities: { drop: ["ALL"] }
      containers:
        - name: mcp-http-bridge
          image: node:22.11-alpine
          command: ["node", "/work/server.js"]
          workingDir: /work
          ports:
            - { name: http, containerPort: 8080, protocol: TCP }
          env:
            - { name: NODE_ENV, value: "production" }
            - { name: PATH, value: "/kubectl:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
            capabilities: { drop: ["ALL"] }
          volumeMounts:
            - { name: bridge-work, mountPath: /work }
            - { name: bridge-script, mountPath: /work/server.js, subPath: server.js }
            - { name: kubectl-bin, mountPath: /kubectl }
            - { name: tmp, mountPath: /tmp }
            - { name: shared-data, mountPath: /projects/data }
            - { name: log-storage, mountPath: /projects/logs }
            - { name: config-storage, mountPath: /projects/config }
            - { name: shared-workspace, mountPath: /projects/workspace }
          resources:
            requests: { memory: "128Mi", cpu: "50m" }
            limits:   { memory: "256Mi", cpu: "200m" }
          livenessProbe:
            httpGet: { path: /health, port: 8080 }
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet: { path: /health, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
      volumes:
        - { name: bridge-work, emptyDir: {} }
        - { name: bridge-script, configMap: { name: filesystem-mcp-bridge-script } }
        - { name: kubectl-bin, emptyDir: {} }
        - { name: tmp, emptyDir: {} }
        - name: shared-data
          persistentVolumeClaim: { claimName: filesystem-mcp-data }
        - name: log-storage
          persistentVolumeClaim: { claimName: filesystem-mcp-logs }
        - name: config-storage
          persistentVolumeClaim: { claimName: filesystem-mcp-config }
        - name: shared-workspace
          persistentVolumeClaim: { claimName: mcp-shared-workspace }
```

**Notes:**
- `package.json` lives in the ConfigMap, NOT in a baked image. Renovate cannot scan ConfigMaps — review express/ws versions quarterly until this is migrated to a proper image.
- The bridge is a stop-gap; the right long-term fix is a baked image with deps and `kubectl` already installed. Track that as follow-up.

- [ ] **Step 2: Validate**

```bash
kustomize build apps/base/mcp-servers/ > /tmp/mcp-build.yaml
# Check securityContext fields
yq 'select(.kind == "Deployment" and .metadata.name == "filesystem-mcp-bridge")
    | .spec.template.spec.containers[0].securityContext' /tmp/mcp-build.yaml
# expected:
#   allowPrivilegeEscalation: false
#   readOnlyRootFilesystem: true
#   runAsNonRoot: true
#   capabilities: {drop: [ALL]}
```

No `add: ["NET_ADMIN"]` should appear anywhere.

- [ ] **Step 3: Stage, review, commit, push**

```bash
git add apps/base/mcp-servers/filesystem-mcp/bridge-deployment.yaml
# Dispatch reviewers, fix blockers, then:
git commit -m "$(cat <<'EOF'
fix(mcp-servers): harden filesystem-mcp-bridge runtime

- Move inline server JS to ConfigMap (no apk/npm install at startup)
- Pin node:22.11-alpine and bitnami/kubectl:1.32.3
- runAsNonRoot, drop ALL caps, allowPrivilegeEscalation: false
- readOnlyRootFilesystem with emptyDir for /work, /kubectl, /tmp
- Remove NET_ADMIN capability

mcp-servers is currently commented out in apps/staging/kustomization.yaml;
this is a preventive fix before re-enable.

P0 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Task 6: Front headlamp with oauth2-proxy + Keycloak

**Prerequisite:** Task 1 manual steps complete (AWS secret `headlamp/oauth2-proxy` exists with all 3 keys).

**ORDER MATTERS:** Step 8 (provision `aws-credentials` SOPS-encrypted Secret in `apps/staging/headlamp/`) MUST be completed AND verified on the cluster BEFORE the commit in Step 10. Otherwise:
1. The new `SecretStore` references `aws-credentials` which doesn't exist → `SecretStore` is NotReady.
2. The `ExternalSecret` can't sync → no `oauth2-proxy-secrets` Secret materializes.
3. The `oauth2-proxy` Deployment CrashLoopBackOffs on missing env-var Secret.
4. The ingress now points at `oauth2-proxy:4180` (down), so the dashboard is 5xx until you fix forward.

Verify before pushing Step 10:
```bash
kubectl get secret aws-credentials -n headlamp -o jsonpath='{.data.access-key-id}' | head -c 8 ; echo
# expected: 8 non-empty base64 chars
```

If you can't satisfy this prereq, defer Task 6 — Tasks 2/3/4/5/7 are independent.

**Files:**
- Create: `apps/base/headlamp/secret-store.yaml`
- Create: `apps/base/headlamp/external-secret-oauth2.yaml`
- Create: `apps/base/headlamp/oauth2-proxy-deployment.yaml`
- Create: `apps/base/headlamp/oauth2-proxy-service.yaml`
- Modify: `apps/base/headlamp/ingress.yaml`
- Modify: `apps/base/headlamp/kustomization.yaml`

- [ ] **Step 1: Inspect existing SecretStore pattern**

The cluster uses `aws-secret-store` (kind SecretStore) per namespace. Check whether the headlamp namespace already has one and what AWS-credentials ExternalSecret pattern is used elsewhere (e.g., oura-dashboard):

```bash
ls apps/base/headlamp/
grep -rn "kind: SecretStore" apps/base/oura-dashboard/ | head
```

If headlamp does not yet have an aws-credentials Secret and SecretStore, we'll need to add them. Refer to `apps/base/oura-dashboard/aws-secret-store.yaml`, `apps/base/oura-dashboard/external-secret-aws.yaml`, and the SOPS-encrypted credentials in `apps/staging/oura-dashboard/`.

**Decision point:** Two options here:
- **A.** Replicate the full oura-dashboard pattern (SOPS-encrypted AWS creds in staging + per-namespace SecretStore). More files.
- **B.** Use a `ClusterSecretStore` if one already exists. Check: `kubectl get clustersecretstore`. If yes, use it and skip per-namespace SecretStore.

Use whichever the cluster already uses. **Most cluster apps use per-namespace `SecretStore` with SOPS-encrypted AWS creds.** Follow that pattern unless ClusterSecretStore is present.

- [ ] **Step 2: Create `apps/base/headlamp/secret-store.yaml`**

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: headlamp
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

- [ ] **Step 3: Create `apps/base/headlamp/external-secret-oauth2.yaml`**

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: oauth2-proxy-secrets
  namespace: headlamp
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: oauth2-proxy-secrets
    creationPolicy: Owner
  data:
    - secretKey: client-id
      remoteRef:
        key: headlamp/oauth2-proxy
        property: client-id
    - secretKey: client-secret
      remoteRef:
        key: headlamp/oauth2-proxy
        property: client-secret
    - secretKey: cookie-secret
      remoteRef:
        key: headlamp/oauth2-proxy
        property: cookie-secret
```

- [ ] **Step 4: Create `apps/base/headlamp/oauth2-proxy-deployment.yaml`** (mirrors oura-dashboard pattern, pinned image)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: headlamp
  labels:
    app: oauth2-proxy
    app.kubernetes.io/part-of: headlamp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: oauth2-proxy
          image: quay.io/oauth2-proxy/oauth2-proxy:v7.11.0
          args:
            - --provider=keycloak-oidc
            - --email-domain=*
            - --upstream=http://headlamp.headlamp.svc.cluster.local:80
            - --http-address=0.0.0.0:4180
            - --reverse-proxy=true
            - --skip-provider-button=true
            - --cookie-secure=true
            - --cookie-domain=headlamp.landryzetam.net
            - --whitelist-domain=.landryzetam.net
            - --cookie-refresh=1h
            - --cookie-expire=24h
            - --ssl-insecure-skip-verify=true
            - --insecure-oidc-allow-unverified-email=true
            - --insecure-oidc-skip-nonce=true
            - --skip-jwt-bearer-tokens=true
            - --skip-auth-regex=^/.well-known/acme-challenge/
            - --oidc-extra-audience=master-realm
            - --oidc-extra-audience=account
            - --skip-oidc-discovery=true
            - --oidc-email-claim=email
            - --oidc-groups-claim=groups
          env:
            - name: OAUTH2_PROXY_CLIENT_ID
              valueFrom: { secretKeyRef: { name: oauth2-proxy-secrets, key: client-id } }
            - name: OAUTH2_PROXY_CLIENT_SECRET
              valueFrom: { secretKeyRef: { name: oauth2-proxy-secrets, key: client-secret } }
            - name: OAUTH2_PROXY_COOKIE_SECRET
              valueFrom: { secretKeyRef: { name: oauth2-proxy-secrets, key: cookie-secret } }
            - name: OAUTH2_PROXY_OIDC_ISSUER_URL
              value: "https://auth.landryzetam.net/realms/master"
            - name: OAUTH2_PROXY_REDIRECT_URL
              value: "https://headlamp.landryzetam.net/oauth2/callback"
            - name: OAUTH2_PROXY_LOGIN_URL
              value: "https://auth.landryzetam.net/realms/master/protocol/openid-connect/auth"
            - name: OAUTH2_PROXY_REDEEM_URL
              value: "https://auth.landryzetam.net/realms/master/protocol/openid-connect/token"
            - name: OAUTH2_PROXY_OIDC_JWKS_URL
              value: "https://auth.landryzetam.net/realms/master/protocol/openid-connect/certs"
          ports:
            - containerPort: 4180
              name: http
          resources:
            requests: { cpu: 10m, memory: 32Mi }
            limits:   { cpu: 100m, memory: 128Mi }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities: { drop: ["ALL"] }
          volumeMounts:
            # /tmp is needed for OIDC discovery cache and any internal scratch.
            - { name: tmp, mountPath: /tmp }
          livenessProbe:
            httpGet: { path: /ping, port: 4180 }
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet: { path: /ping, port: 4180 }
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: tmp
          emptyDir:
            medium: Memory
            sizeLimit: 16Mi
```

- [ ] **Step 5: Create `apps/base/headlamp/oauth2-proxy-service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: headlamp
spec:
  selector:
    app: oauth2-proxy
  ports:
    - port: 4180
      targetPort: 4180
      protocol: TCP
      name: http
  type: ClusterIP
```

- [ ] **Step 6: Modify `apps/base/headlamp/ingress.yaml`** — switch backend

Replace:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: headlamp
  namespace: headlamp
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - headlamp.landryzetam.net
      secretName: headlamp-tls
  rules:
    - host: headlamp.landryzetam.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: oauth2-proxy
                port:
                  number: 4180
```

(Only change vs. current file is `service.name: headlamp` → `oauth2-proxy` and `port.number: 80` → `4180`.)

- [ ] **Step 7: Modify `apps/base/headlamp/kustomization.yaml`** — add new resources

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: headlamp

resources:
  - namespace.yaml
  - rbac.yaml
  - admin-serviceaccount.yaml
  - deployment.yaml
  - service.yaml
  - secret-store.yaml
  - external-secret-oauth2.yaml
  - oauth2-proxy-deployment.yaml
  - oauth2-proxy-service.yaml
  - ingress.yaml

labels:
- pairs:
    app.kubernetes.io/name: headlamp
    app.kubernetes.io/part-of: dashboard
    app.kubernetes.io/managed-by: kustomize
```

- [ ] **Step 8: Provision the `aws-credentials` Secret in the headlamp namespace**

The SecretStore needs an `aws-credentials` Secret. Use the same pattern as other apps (SOPS-encrypted Secret in `apps/staging/headlamp/`). Copy from a working example:

```bash
./scripts/secrets/sops-secrets.sh copy
# follow prompts: source namespace = oura-dashboard, target = headlamp
```

Verify after FluxCD reconciles:

```bash
kubectl get secret aws-credentials -n headlamp
kubectl get secretstore aws-secret-store -n headlamp -o yaml | yq .status
```

- [ ] **Step 9: Validate full build**

```bash
mkdir -p apps/staging/headlamp # if missing
# Ensure apps/staging/headlamp/kustomization.yaml references ../../base/headlamp/
kustomize build apps/staging/headlamp/ > /tmp/headlamp-full.yaml
kubectl apply --dry-run=server -f /tmp/headlamp-full.yaml
```

- [ ] **Step 10: Stage, review, commit, push**

```bash
git add apps/base/headlamp/secret-store.yaml \
        apps/base/headlamp/external-secret-oauth2.yaml \
        apps/base/headlamp/oauth2-proxy-deployment.yaml \
        apps/base/headlamp/oauth2-proxy-service.yaml \
        apps/base/headlamp/ingress.yaml \
        apps/base/headlamp/kustomization.yaml \
        apps/staging/headlamp/  # if any new SOPS secret files were added
# Dispatch reviewers, fix blockers, then:
git commit -m "$(cat <<'EOF'
feat(headlamp): front with oauth2-proxy + Keycloak SSO

Previously the dashboard was reachable at headlamp.landryzetam.net with
only the in-app token field as auth. Now Keycloak (master realm,
'headlamp' client) gates access before any traffic reaches the dashboard
backend. Pattern matches oura-dashboard oauth2-proxy.

Requires AWS secret /headlamp/oauth2-proxy with client-id, client-secret,
cookie-secret. See docs/operations/headlamp-keycloak-client.md.

P0 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
flux reconcile kustomization apps --with-source
```

- [ ] **Step 11: Functional verify**

```bash
kubectl get pods -n headlamp
# expected: headlamp-* Ready, oauth2-proxy-* Ready

# Force a fresh browser session and visit https://headlamp.landryzetam.net/
# Expected: redirect to https://auth.landryzetam.net/realms/master/protocol/openid-connect/auth?...
# After Keycloak login: redirect back to headlamp with cookie set
# Expected: headlamp UI loads
```

If the redirect loops or fails: check `kubectl logs -n headlamp deployment/oauth2-proxy` for OIDC errors.

---

## Task 7: Harden claude-code pod (active component)

**Files:**
- Modify: `apps/base/claude-code/deployment.yaml`

The current pod runs as root, uses `:latest`, exposes SSH publicly, holds an OAuth token. The full fix (move off SSH-based n8n orchestration) is out of scope. **Minimum hardening** here:

- Pin to a SHA-tagged image
- Add `securityContext` (pod + container)
- Add resource limits if missing (already present)
- Drop unnecessary capabilities

- [ ] **Step 1: Determine a pinned tag**

```bash
# Inspect available tags
curl -s "https://hub.docker.com/v2/repositories/lzetam/claude-code/tags?page_size=20" \
  | jq -r '.results[].name' | head -10
```

Pick the most recent semver-tagged or SHA-tagged image. If only `:latest` exists, build & push a tagged version FIRST in the claude-code source repo. **Do not proceed with `:latest`.**

- [ ] **Step 2: Modify `apps/base/claude-code/deployment.yaml`**

Change `image: lzetam/claude-code:latest` to the tagged image (example uses placeholder `<TAG>` — replace with the actual tag from Step 1):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claude-code
  namespace: claude-code
  labels:
    app: claude-code
spec:
  replicas: 1
  selector:
    matchLabels:
      app: claude-code
  template:
    metadata:
      labels:
        app: claude-code
    spec:
      serviceAccountName: default
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      imagePullSecrets:
        - name: dockerhub-registry
      containers:
        - name: claude-code
          image: lzetam/claude-code:<TAG>
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 22
              name: ssh
          env:
            - name: CLAUDE_CODE_OAUTH_TOKEN
              valueFrom:
                secretKeyRef:
                  name: claude-code-oauth
                  key: oauth-token
          volumeMounts:
            - name: ssh-pubkey
              mountPath: /home/claude/.ssh
              readOnly: true
          resources:
            requests: { cpu: "50m", memory: 64Mi }
            limits:   { cpu: "1",   memory: 1Gi }
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            capabilities:
              drop: ["ALL"]
              # REQUIRED: sshd binds port 22 (<1024), so the process needs
              # NET_BIND_SERVICE to bind it as a non-root user. Removing this
              # cap requires reconfiguring sshd in the image to bind a port
              # >=1024 AND updating the Service/ingress/livenessProbe accordingly.
              add: ["NET_BIND_SERVICE"]
          livenessProbe:
            exec:
              command: ["service", "ssh", "status"]
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            tcpSocket: { port: 22 }
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: ssh-pubkey
          configMap:
            name: claude-code-ssh-pubkey
            defaultMode: 0600
            items:
              - { key: authorized_keys, path: authorized_keys }
```

**Note:** The YAML above includes `capabilities.add: ["NET_BIND_SERVICE"]` because sshd in the image binds port 22 (< 1024) as a non-root user. Removing this cap requires reconfiguring sshd to bind port >=1024 AND updating the Service, n8n SSH client, ingress port, and livenessProbe — that's a separate, more invasive change. For now, retain the capability.

- [ ] **Step 3: Validate**

```bash
kustomize build apps/staging/claude-code/ > /tmp/claude-build.yaml
kubectl apply --dry-run=server -f /tmp/claude-build.yaml
```

- [ ] **Step 4: Stage, review, commit, push**

```bash
git add apps/base/claude-code/deployment.yaml
# Dispatch reviewers, fix blockers, then:
git commit -m "$(cat <<'EOF'
fix(claude-code): pin image, add securityContext, drop caps

- Pin lzetam/claude-code from :latest to versioned tag
- runAsNonRoot, drop ALL caps, allowPrivilegeEscalation: false
- automountServiceAccountToken: false (pod does not call K8s API)
- seccompProfile: RuntimeDefault

P0 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
flux reconcile kustomization apps
kubectl rollout status deployment/claude-code -n claude-code
```

If the pod fails to start because sshd needs `NET_BIND_SERVICE`, revert with `git revert HEAD --no-edit && git push`, then apply the variant with `capabilities.add: ["NET_BIND_SERVICE"]`.

---

## Per-commit review workflow

For EVERY commit in this plan, before `git push`:

```bash
# 1. Stage the change
git add <files>

# 2. Run reviewers in parallel (single message, two Agent calls)
#    code-reviewer: general quality
#    security-reviewer: RBAC/secret/network risks
```

Then dispatch:

- **code-reviewer**: "Review staged changes. Focus: correctness, kustomize-build cleanliness, YAML schema."
- **security-reviewer**: "Review staged changes. Focus: RBAC verb scoping, secret handling, network exposure, privilege escalation, capability adds."

If either returns Blockers or Critical findings:
1. Fix them
2. Re-stage
3. Re-dispatch reviewers
4. Only commit when both pass

Push after commit. Wait for Flux reconcile, then run the verification step listed in each task.

---

## Self-Review Notes

**Spec coverage:**
- ✅ Headlamp cluster-admin removal → Task 3
- ✅ Headlamp ClusterRole wildcard → Task 2
- ✅ Headlamp oauth2-proxy fronting → Tasks 1 + 6
- ✅ kubernetes-mcp-server cluster-wide secret writes → Task 4
- ✅ filesystem-mcp-bridge NET_ADMIN + root + dynamic kubectl → Task 5
- ✅ claude-code bonus hardening → Task 7

**Caveats the executor must respect:**
- Task 6 BLOCKS on Task 1's AWS secret existing. Do not deploy oauth2-proxy with empty/missing secret — pods will crashloop.
- Task 5 has a known structural issue in the example YAML: two `initContainers:` blocks. Merge into one ordered list before applying.
- Task 7 may require `NET_BIND_SERVICE` if the image runs sshd on port 22.
- mcp-servers is currently commented out in apps/staging — fixes are git-only, no rollout impact.

**Out-of-scope items moved to other plans:**
- Image pinning (38+ apps) → `2026-05-11-p1-image-pinning.md`
- PSS baseline → `2026-05-11-p1-podsecurity-baseline.md`
- NetworkPolicies → `2026-05-11-p2-networkpolicies.md`
- SecurityContext rollout → `2026-05-11-p2-securitycontext-rollout.md`
