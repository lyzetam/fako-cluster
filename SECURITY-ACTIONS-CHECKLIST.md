# SECURITY AUDIT ACTION CHECKLIST
## Fako Cluster - Do This Today

**Status:** CRITICAL - Start with IMMEDIATE actions below

---

## IMMEDIATE ACTIONS (Do Today - 1 hour total)

### 1. Disable Headlamp Public Access - CRITICAL
**File:** `/apps/base/headlamp/ingress.yaml`
**Action:**
```bash
# Option A: Delete the ingress (disable public access)
cd /Users/zz/dev/fako-cluster
git rm apps/base/headlamp/ingress.yaml

# Then access via port-forward only:
kubectl port-forward -n headlamp svc/headlamp 4466:80
# Visit: http://localhost:4466 (only from your machine)

# Commit:
git add . && git commit -m "fix(headlamp): remove public ingress, require port-forward access"
git push origin main
```

**Verify:**
- Headlamp should NOT be accessible at headlamp.landryzetam.net
- Still accessible via: `kubectl port-forward -n headlamp svc/headlamp 4466:80`

**Why:** Full cluster admin access without any authentication = complete infrastructure compromise in 2 minutes

---

### 2. Disable pgAdmin Public Access - CRITICAL
**File:** `/apps/base/pgadmin/ingress.yaml`
**Action:**
```bash
# Option A: Delete the ingress (disable public access)
cd /Users/zz/dev/fako-cluster
git rm apps/base/pgadmin/ingress.yaml

# Then access via port-forward only:
kubectl port-forward -n pgadmin svc/pgadmin 5050:80
# Visit: http://localhost:5050 (only from your machine)

# Commit:
git add . && git commit -m "fix(pgadmin): remove public ingress, require port-forward access"
git push origin main
```

**Verify:**
- pgAdmin should NOT be accessible at pgadmin.landryzetam.net
- Still accessible via: `kubectl port-forward -n pgadmin svc/pgadmin 5050:80`

**Why:** Database admin tool without auth = can delete all data or exfiltrate everything

---

### 3. Audit git history for secrets - CRITICAL
**Action:**
```bash
cd /Users/zz/dev/fako-cluster

# Install gitleaks if not present
brew install gitleaks

# Scan for secrets
gitleaks detect --source . -v

# If ANY secrets found:
# 1. Rotate the credentials in AWS immediately
# 2. Note which commits exposed them
# 3. Document in security audit
```

**What to look for:**
- AWS access keys (AKIA*)
- API keys (sk-*, api_key=)
- Database passwords (password=, passwd=)
- Private SSH keys

**Why:** Attacker can use git history to find old credentials

---

### 4. Update GitHub README - HIGH
**File:** `/README.md`
**Current Version (Remove These):**
```
UGREEN NAS at 10.85.30.127
RTX 5070 + RTX 3050
postgres-cluster-rw.postgres.svc.cluster.local
headlamp.landryzetam.net, pgadmin.landryzetam.net, ollama.landryzetam.net
```

**Action:**
```bash
# Edit README.md - remove specific IPs, internal DNS names, exact model numbers
# Keep only:
- "K3s homelab with 7 nodes"
- "GPU acceleration for AI workloads"
- General architecture diagram without specific hostnames
- DO NOT list all 40+ services with their DNS names

# Commit:
git add README.md && git commit -m "docs: remove infrastructure fingerprints from public README"
git push origin main
```

**Why:** Attackers use this info to create targeted attack plans

---

## SHORT-TERM ACTIONS (This Week)

### 5. Rate Limit Ollama API - HIGH
**File:** `/apps/base/ollama/ingress.yaml`
**Action:**
```yaml
# Add rate limiting to prevent DoS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ollama
  namespace: ollama
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-production"
    traefik.ingress.kubernetes.io/router.middlewares: ollama-ratelimit@kubernetescrd
spec:
  # ... rest of ingress config
---
# Create rate limit middleware
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: ollama-ratelimit
  namespace: ollama
spec:
  rateLimit:
    average: 10  # 10 requests per minute
    period: 1m
```

**Commit:**
```bash
git add apps/base/ollama/ingress.yaml && git commit -m "fix(ollama): add rate limiting middleware"
git push origin main
```

**Why:** Prevents attackers from DoS-ing your GPU with 1000 concurrent requests

---

### 6. Implement Network Policies - HIGH
**Priority Order:**
1. Start with postgres namespace
2. Then high-value services: keycloak, n8n, family-manager

**Example for postgres namespace:**
```yaml
# apps/base/postgres-cluster/network-policy.yaml
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
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: postgres
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Then label namespaces that need DB access:**
```bash
kubectl label namespace oura-collector db-access=true
kubectl label namespace n8n db-access=true
kubectl label namespace quantum-trades db-access=true
# (only the ones that actually need it)
```

**Why:** Stops lateral movement - if one pod compromised, others are still protected

---

### 7. Verify pgAdmin Credentials Location - MEDIUM
**Action:**
```bash
# Check where pgAdmin credentials are stored
kubectl get configmap -n pgadmin -o yaml | grep -i password

# If password is in ConfigMap (BAD):
# 1. Move to ExternalSecret immediately
# 2. Delete the ConfigMap

# Should see:
# External Secret syncing from AWS Secrets Manager
# NOT password stored in ConfigMap
```

**Why:** ConfigMap passwords visible to anyone with kubectl access

---

### 8. Remove Privileged Mode from mcp-gateway - HIGH
**File:** `/apps/base/mcp-gateway/deployment.yaml`
**Current:**
```yaml
securityContext:
  privileged: true  # DANGEROUS
```

**Action:**
```bash
# First, test if mcp-gateway works without privileged mode
# Edit deployment to remove: privileged: true

# If Docker is needed, use Docker socket binding instead:
volumeMounts:
- name: docker-socket
  mountPath: /var/run/docker.sock
volumes:
- name: docker-socket
  hostPath:
    path: /var/run/docker.sock

# Commit:
git add apps/base/mcp-gateway/deployment.yaml
git commit -m "fix(mcp-gateway): remove privileged mode, use socket binding"
git push origin main
```

**Why:** Privileged containers can escape to host and compromise entire node

---

## LONG-TERM ACTIONS (Next Month)

### 9. Create Private Infrastructure Mirror Repo
**Action:**
1. Create new private GitHub repo: `fako-cluster-private`
2. Move sensitive manifests there (not the public repo)
3. Use git submodules or separate branches

**Why:** Public repo shows exactly how to attack your infrastructure

---

### 10. Implement Pod Security Standards
**Action:**
```bash
# Enable pod security policies cluster-wide
kubectl apply -f - <<EOF
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  runAsUser:
    rule: 'MustRunAsNonRoot'
EOF
```

**Why:** Prevents containers from running as root cluster-wide

---

### 11. Implement IRSA for AWS Credentials
**Instead of:** Storing AWS access keys in Kubernetes secrets
**Use:** Kubernetes Service Account IAM (IRSA)
- ExternalSecrets gets temporary credentials via STS
- Avoids long-term key storage
- More secure key rotation

**Why:** If cluster is compromised, AWS account stays protected

---

### 12. Add Egress NetworkPolicies
**Example for voice-pipeline:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: voice-pipeline-egress
  namespace: voice-pipeline
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow to Ollama only
  - to:
    - podSelector:
        matchLabels:
          app: ollama-gpu
    ports:
    - protocol: TCP
      port: 11434
  # Allow to DNS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
  # Deny all else (including internet)
```

**Why:** Stops data exfiltration if pod is compromised

---

## VERIFICATION CHECKLIST

After each action, verify:

- [ ] Headlamp not accessible at https://headlamp.landryzetam.net
- [ ] pgAdmin not accessible at https://pgadmin.landryzetam.net
- [ ] Port-forward access still works for both
- [ ] No secrets found in git history
- [ ] Ollama has rate limiting
- [ ] Network policies block lateral movement
- [ ] mcp-gateway no longer runs as privileged
- [ ] All deployments pushed to main branch
- [ ] Flux reconciliation completed: `flux get all -A`

---

## TESTING ATTACKS AFTER FIXES

### Test Headlamp Protection:
```bash
# Should fail (GOOD):
curl https://headlamp.landryzetam.net/

# Should work (GOOD):
kubectl port-forward -n headlamp svc/headlamp 4466:80
# Then http://localhost:4466 works
```

### Test Ollama Rate Limiting:
```bash
# Should hit rate limit quickly:
for i in {1..20}; do curl -X POST https://ollama.landryzetam.net/api/generate -d '{"model":"test"}' & done
```

### Test Network Policy:
```bash
# Try to reach postgres from open-webui (should fail):
kubectl exec -n open-webui deploy/open-webui -- nc -zv postgres-cluster-rw.postgres 5432

# Should show: "Connection refused" (GOOD)
```

---

## TIMELINE

- **Hour 1:** Actions 1, 2, 3, 4 (disable bad access, check history, update README)
- **Day 1 evening:** Action 5 (rate limiting)
- **This week:** Actions 6, 7, 8 (network policies, credentials, privileged mode)
- **Next month:** Actions 9, 10, 11, 12 (long-term hardening)

---

## IF YOU GET STUCK

1. **Headlamp removal issues?** See: `/apps/base/oura-dashboard/oauth2-proxy.yaml` for auth pattern
2. **Network policy issues?** Start simple: just block postgres, add others later
3. **Git history issues?** Contact me, don't delete history (might need for audit)
4. **Flux not reconciling?** Run: `flux reconcile source git flux-system && flux reconcile kustomization apps`

---

**DO NOT SKIP THE IMMEDIATE ACTIONS** - Headlamp and pgAdmin are literally the two biggest risks to your cluster.
