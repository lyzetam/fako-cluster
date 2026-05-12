# P1 Image Pinning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every `image: <name>:latest` reference in `apps/base/` with a versioned/SHA-pinned tag so Renovate can track CVEs, deploys are reproducible, and rollbacks are deterministic.

**Architecture:** Group fixes by source registry. For `lzetam/*` images, push a tagged version of the currently-deployed image to DockerHub first (so we don't accidentally pin to an older `:latest` digest), then update the manifest. For public images, look up the latest stable semver tag.

**Tech Stack:** Docker Hub, GitHub Container Registry, Renovate, FluxCD.

---

## File Structure

**Inventory of `:latest` references (from 2026-05-11 audit):**

| Group | Count | Files |
|---|---|---|
| `lzetam/*` (own images) | ~50 | quantum-trades (9), zi (8), nick-brothers (4), market-replay (4), ai-news (5), family-manager (3), oura (4), thornus (2), phoenix (2), task-tracker (3), n3xis, blog, lzt-ui, autobots, kube-bench-reporter, kubescape-reporter, oura-dashboard, oura-agent, claude-code (covered in P0), ai-mastery-path, audio-workflows, meal-tracker (2), sermon-engine, unifi-clients, whisperx |
| `bitnami/kubectl:latest` | ~10 | create-docker-registry-secret-job templates: unifi-clients, lzt-ui, ai-news, audio-workflows, n8n, kubescape-operator, ai-mastery-path, connor-birthday, n8n-migration, housekeeping |
| `mcp/*` and `chromadb/chroma:latest` | 5 | mcp-servers/{sequentialthinking,memory,weather,vector-db,time,n8n,postgres}-mcp |
| `ollama/ollama:latest` | 4 | ollama-jetson, ollama-jetson2 (two refs each) |
| Other public | 8 | `busybox:latest` (zi, postgres-cluster), `node:18-alpine`, `donetick/donetick:latest`, `rhasspy/wyoming-piper:latest`, `rhasspy/wyoming-openwakeword:latest`, `curlimages/curl:latest` (nick-brothers), `lscr.io/linuxserver/piper:latest`, `ghcr.io/speaches-ai/speaches:latest-cpu` (2 refs), `ghcr.io/kubebeam/kubescape-headlamp-plugin:latest` |

**Files modified:** ~80 manifests (see full list in `grep -rln "image:.*:latest" apps/base/`)
**Files created:** none
**Renovate impact:** all pinned tags become trackable; PRs will start arriving as new versions release.

---

## Task 1: Inventory + reset baseline

- [ ] **Step 1: Generate the canonical list**

```bash
cd /Users/zz/dev/fako-cluster
grep -rn "image:.*:latest" apps/base/ > /tmp/latest-images.txt
wc -l /tmp/latest-images.txt
```

- [ ] **Step 2: For each `lzetam/*` `:latest`, find what's currently running**

```bash
for ref in $(awk -F'image:' '/lzetam/{print $2}' /tmp/latest-images.txt | awk '{print $1}' | sort -u); do
  name=$(echo $ref | cut -d: -f1 | sed 's|lzetam/||')
  echo "=== $name ==="
  kubectl get pods -A -o json | jq -r '.items[] | .status.containerStatuses[]? | select(.image | test("'"$ref"'$")) | "\(.imageID)"' | sort -u | head -1
done > /tmp/lzetam-current-digests.txt
```

This produces `imageID` references like `docker.io/lzetam/quantum-trades-trading@sha256:abc...`. These are the *currently deployed* digests — use them to derive a pinned tag.

- [ ] **Step 3: Decide tag strategy**

For each `lzetam/*` image:
- If the source repo has a CI that tags on push (e.g., `sha-<short>` or git semver): use the tag matching the current digest.
- If only `:latest` exists: in the source repo, tag the current commit and push:
  ```bash
  # in the source project, e.g., ~/dev/quantum-trades
  git tag v$(date +%Y.%m.%d)
  git push --tags
  # CI rebuilds and pushes lzetam/quantum-trades-trading:v2026.05.11
  ```
  OR re-tag the existing image directly:
  ```bash
  docker pull lzetam/quantum-trades-trading:latest
  docker tag lzetam/quantum-trades-trading:latest lzetam/quantum-trades-trading:v2026.05.11
  docker push lzetam/quantum-trades-trading:v2026.05.11
  ```

Document the chosen tag per image in `notes/docs/operations/image-tag-baseline-2026-05-11.md`.

---

## Task 2: Pin `lzetam/*` images per app group

Per app, replace `:latest` with the pinned tag. Each app is its own commit.

**Canonical pattern:**

```yaml
# Before
image: lzetam/quantum-trades-trading:latest

# After
image: lzetam/quantum-trades-trading:v2026.05.11
```

**Apps to do (one commit each):**

- [ ] quantum-trades (9 files: backend, frontend, trading, backtesting, signals, strategies, technicals, orchestrator-qt, cronjob-scanner)
- [ ] zi (deployment.yaml, agents.yaml, configmap-generators.yaml, zi-dashboard-deployment.yaml) — note: `agents.yaml` is a generated file; modify the generator script in `apps/base/zi-agents/` instead
- [ ] nick-brothers (dashboard, website, backend, agent-scheduler-cronjob curl:latest)
- [ ] market-replay (gateway, replay, recorder, backfill)
- [ ] ai-news (api + 4 cronjobs)
- [ ] family-manager (deployment, deployment-bot, cronjob-email)
- [ ] oura group (oura-collector, oura-agent, oura-dashboard)
- [ ] thornus (frontend, backend)
- [ ] phoenix (backend, frontend)
- [ ] task-tracker (deployment, backend, frontend)
- [ ] Standalone: n3xis, blog, lzt-ui, autobots, ai-mastery-path, sermon-engine, unifi-clients, whisperx
- [ ] Reporters: kube-bench/cronjob-reporter, kubescape-operator/cronjob-reporter
- [ ] meal-tracker (deployment, dashboard)
- [ ] audio-workflows/workflow-template

**Per-app workflow:**

```bash
# Edit files
git add apps/base/<app>/
git diff --staged
# Reviewers (code-reviewer for general; no security-reviewer needed for tag pins)
git commit -m "chore(<app>): pin image tags off :latest

Renovate-trackable, reproducible rollback. Baseline tag is the digest
deployed on 2026-05-11 (see notes/docs/operations/image-tag-baseline-2026-05-11.md).

P1 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin main
flux reconcile kustomization apps
kubectl rollout status deployment/<name> -n <namespace>
```

**Validation per app:**
- `kustomize build apps/staging/<app>/ | grep "image:"` shows no `:latest`
- After reconcile, pods are Ready
- Renovate dashboard issue (#89) eventually shows the new image as trackable

---

## Task 3: Pin public images

| Image | Find latest | Replacement strategy |
|---|---|---|
| `bitnami/kubectl:latest` | `docker pull bitnami/kubectl:1.32.3` (match cluster K8s version) | Replace in all 10 `create-docker-registry-secret-job.yaml` + `housekeeping/cronjob.yaml` + `n8n-migration/01-export-job.yaml` |
| `busybox:latest` | `busybox:1.37.0` | postgres-cluster/pvc-and-permissions.yaml, zi/deployment.yaml |
| `node:18-alpine` (filesystem-mcp-bridge) | Covered in P0 plan Task 5 | n/a |
| `donetick/donetick:latest` | Check upstream releases | donetick/deployment.yaml |
| `rhasspy/wyoming-piper:latest` | Check Wyoming releases | piper/deployment.yaml |
| `rhasspy/wyoming-openwakeword:latest` | Check Wyoming releases | openwakeword/deployment.yaml |
| `lscr.io/linuxserver/piper:latest` | Check LinuxServer releases | piper-v13/deployment.yaml |
| `ghcr.io/speaches-ai/speaches:latest-cpu` | Find latest semver tag | whisper-cpu/deployment.yaml (2 refs) |
| `ghcr.io/kubebeam/kubescape-headlamp-plugin:latest` | Find latest semver tag | headlamp/deployment.yaml (initContainer) |
| `curlimages/curl:latest` | `curlimages/curl:8.10.1` | nick-brothers/agent-scheduler-cronjob.yaml |
| `ollama/ollama:latest` | `ollama/ollama:0.5.4` | ollama-jetson, ollama-jetson2 (2 refs each) |
| `mcp/sequentialthinking:latest` | Check mcp/* on Docker Hub | mcp-servers/sequentialthinking-mcp/deployment.yaml |
| `mcp/memory:latest` | Same | mcp-servers/memory-mcp/deployment.yaml |
| `mcp/openweather:latest` | Same | mcp-servers/weather-mcp/deployment.yaml |
| `mcp/time:latest` | Same | mcp-servers/time-mcp/deployment.yaml |
| `chromadb/chroma:latest` | `chromadb/chroma:0.5.23` | mcp-servers/vector-db-mcp/deployment.yaml |

- [ ] **Step 1: For each row above, look up the current stable tag**

```bash
# Docker Hub example
curl -s "https://hub.docker.com/v2/repositories/donetick/donetick/tags?page_size=20" | jq -r '.results[].name' | head -10

# GHCR example (needs PAT for private; for public packages):
curl -s "https://ghcr.io/v2/speaches-ai/speaches/tags/list" | jq -r '.tags[]' | sort -V | tail -10
```

- [ ] **Step 2: One commit per logical group**

Suggested grouping:
1. All `bitnami/kubectl:latest` → `bitnami/kubectl:1.32.3` (one commit)
2. All `busybox:latest` (one commit)
3. All `mcp/*:latest` (one commit, mcp-servers dormant — safe)
4. Voice stack (piper, piper-v13, openwakeword, whisper-cpu) (one commit)
5. ollama-jetson + ollama-jetson2 (one commit)
6. Remaining one-offs: donetick, curl, chroma, kubescape-plugin (one commit each)

**Per-commit:**

```bash
git add <files>
git commit -m "chore(images): pin <group> off :latest

P1 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin main
flux reconcile kustomization apps
```

---

## Task 4: Pin gpu-operator HelmRelease

**File:** `infrastructure/controllers/base/gpu-operator/release.yaml`

The release pins `version: "*"` (Helm's "latest"). Replace with a semver range.

- [ ] **Step 1: Determine the currently installed version**

```bash
helm list -n gpu-operator
# note the CHART column, e.g., gpu-operator-v24.9.1
```

- [ ] **Step 2: Edit release.yaml**

```yaml
# Before
chart:
  spec:
    chart: gpu-operator
    version: "*"
    sourceRef:
      kind: HelmRepository
      name: nvidia

# After (match installed minor; allow patch upgrades)
chart:
  spec:
    chart: gpu-operator
    version: ">=24.9.0 <25.0.0"
    sourceRef:
      kind: HelmRepository
      name: nvidia
```

- [ ] **Step 3: Validate, commit, push**

```bash
kustomize build infrastructure/controllers/base/gpu-operator/ | kubectl apply --dry-run=server -f -
git add infrastructure/controllers/base/gpu-operator/release.yaml
git commit -m "chore(gpu-operator): pin HelmRelease version to semver range

Was 'version: *' which is Helm's 'latest'. Now constrained to the 24.x
minor; Renovate-trackable.

P1 finding from 2026-05-11 platform-security audit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin main
flux reconcile source helm --all
flux reconcile helmrelease gpu-operator -n gpu-operator
```

---

## Task 5: Refuse-`:latest` policy (preventive)

- [ ] **Step 1: Add a pre-commit guard**

Create `.github/workflows/no-latest-tags.yml`:

```yaml
name: no-latest-tags
on:
  pull_request:
    paths:
      - "apps/**/*.yaml"
      - "infrastructure/**/*.yaml"
      - "monitoring/**/*.yaml"
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Fail on :latest in image refs
        run: |
          set -e
          if grep -rn 'image:.*:latest' apps/ infrastructure/ monitoring/; then
            echo "Found :latest image references. Pin to a versioned tag."
            exit 1
          fi
```

- [ ] **Step 2: Commit and push**

```bash
git add .github/workflows/no-latest-tags.yml
git commit -m "chore(ci): block new :latest image tags on PR

Now that all existing :latest refs are pinned, prevent regression.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push origin main
```

---

## Self-Review

- ✅ Every `:latest` from the audit list mapped to a task
- ✅ Strategy for `lzetam/*` (re-tag current digest) clear
- ✅ CI guard added in Task 5 to prevent regression
- ✅ Renovate impact documented
- ⚠ Some public images need manual version lookup at execution time (Task 3 Step 1)
