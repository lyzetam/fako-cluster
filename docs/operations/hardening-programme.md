# Hardening programme — one traffic model, three enforcement points

Status: **plan. Nothing in Stages 1–5 is applied.** Stage 0 items are small,
independently reversible fixes to things that are already broken or inert.

---

## The single idea

Everything found on 2026-08-18 is one problem wearing three faces:

- **In the cluster**, 19 NetworkPolicies are enforced across 11 of 79 namespaces.
- **On the network**, all 10 VLANs sit in one zone with Allow All between them.
- **The guards that do exist** are unenforced (a `CiliumNetworkPolicy` with no
  Cilium), brittle (rules pinned to DHCP addresses), or switched off
  (`runtimeDetection: disable`).

Fixing these separately means doing the same discovery work three times and
getting three inconsistent answers. They share one input: **who actually talks
to whom.** Kubescape's node-agent already measures exactly that, continuously,
via eBPF — 371 workload policies and 371 ApplicationProfiles built from observed
traffic.

So the programme is:

```
        Kubescape eBPF observation  (already running, already paid for)
                     │
                     ▼
        ┌──── one committed traffic model ────┐
        │   hosts, flows, ports, by name      │
        └──┬──────────────┬──────────────┬────┘
           │              │              │
           ▼              ▼              ▼
   NetworkPolicy      UniFi zones    Runtime detection
   (east-west,        (north-south,  (behavioural
    in-cluster)        cross-VLAN)    baselines)
```

Derive all three enforcement points from one model. Never hand-write the same
fact twice.

**The scheduling win:** both the cluster and the firewall need a "watch before
you block" period. Those two waits are the same activity at different layers, so
they run *concurrently* starting in Stage 1 — not one after the other. That
turns two sequential weeks into one.

---

## Stage 0 — Fix what is already broken or inert

No design decisions. Each is small and independently reversible. Do these first
because two of them are actively costing you protection you already own.

| # | Item | Why now | Risk |
|---|---|---|---|
| 0.1 | ~~**Delete the Cilium wreckage**~~ — **DONE 2026-08-18.** Removed: the Helm release stuck in `uninstalling` for 193 days (cilium-1.19.0), all 12 CRDs, 5 `CiliumNode` CRs, and the `cilium-operator-resource-lock` lease. Calico was never present — confirmed zero CRDs, namespaces, releases or pods. | Verified by the test that matters: the API server now **rejects** a `CiliumNetworkPolicy` with `could not find the requested resource`, where yesterday it accepted one and silently enforced nothing. The 19 real NetworkPolicies are untouched. | Done. |
| 0.2 | **Enable `runtimeDetection`** + raise node-agent memory | The node-agent already runs on every node and has built 371 ApplicationProfiles. The detection engine that consumes them is off — you pay the eBPF cost and get none of the detection. | Low, but **memory is the real risk**: one node-agent is at 872Mi against a 1400Mi limit. Raise the limit in the same commit. |
| 0.3 | **Fix kube-state-metrics** | It has restarted 4 times (most recent 4h ago, reason `Error`) and measured 74.8% scrape availability over 6h. *Every* KSM-based alert in the cluster is degraded, including the new backup alerts. | Low. Diagnostic first — find why it dies. |
| 0.4 | **Block egress to 169.254.169.254** | `family-manager` and `meal-tracker` reach for the cloud metadata endpoint — an AWS SDK hunting for instance credentials that do not exist on-prem. Harmless today, classic SSRF target. | Trivial. |
| 0.5 | **Set the three inert Kubescape capabilities to `disable`** | `httpDetection`, `networkEventsStreaming`, `nodeProfileService` are enabled but render false — the config claims coverage it does not deliver. | Trivial. |
| 0.6 | **Vault write observability** — DHCP reservation for 10.85.10.229, plus a freshness watchdog and alert for every vault writer | **This is the highest-value item in the programme.** See below. | Low — additive only. |

### 0.6 is the one that actually keeps biting

**15 apps write to the Obsidian vault. Two of them have any watchdog. No alert
rule anywhere in `monitoring/` mentions the vault at all.**

| Writers | `alpha-scribe`, `audio-workflows`, `fieldy-webhook`, `hume-collector`, `kube-bench`, `kubescape-operator`, `oura-collector`, `plaud-collector`, `quantum-trades`, `remarkable-ocr`, `social-media`, `tldr-pipeline`, `voice-ingest`, `withings-collector`, `zi` |
|---|---|
| Have a watchdog | `fieldy-webhook`, `quantum-trades` |
| Alerting on vault writes | none |

That is why the July outage ran from 2026-07-15 to 2026-08-17 — **a month** —
before anyone noticed, and why today's ran unseen until it was stumbled over.
The apps log a warning and carry on; nothing escalates.

Every network-layer fix in this programme reduces the *chance* of a vault
outage. This one changes how long an outage lasts from a month to minutes, and
it works no matter what causes the break — policy, DHCP, the host being off, the
plugin crashing. Two things:

1. **DHCP reservation** for the vault host (10.85.10.229). Its address moving is
   the root cause of every incident in this family, twice over.
2. **A freshness check per writer** — assert the expected file appeared, and
   alert when it did not. `fieldy-webhook`'s existing healthcheck CronJob is the
   working pattern to copy.

**Exit criteria:** no Cilium CRDs, no stuck Helm release; runtime detection
producing alerts into Alertmanager; KSM stable for 24h; a vault-freshness alert
that fires when writes stop.

---

## Stage 1 — Build the traffic model (the keystone)

This is the piece that makes Stages 3 and 4 derivative rather than bespoke. It
is also the only stage that involves writing new tooling.

**1.1 — Widen the observation window.** The current learning period is 24h. A
weekly or monthly CronJob's traffic is invisible in it. Extend it, and *start the
clock now* so the wait overlaps everything else.

**1.2 — Start the firewall's observation in parallel.** Phase 0 of
`unifi-firewall-plan.md` is logging-only Allow rules on the UniFi side. It has
the same 7-day wait. Begin it the same day as 1.1.

**1.3 — Write the generator.** A script that turns
`GeneratedNetworkPolicy` objects into repo-shaped manifests. The transforms are
mechanical and already known:

| Observed | Emit | Why |
|---|---|---|
| `/32` to a LAN host | the containing `/24` | 112 pins collapse to 14 hosts in 4 subnets. `/32` pins are what broke the vault twice. |
| `/32` to an external host | the existing allow-public-443 pattern | 2,281 pins, one policy with 109. Discord/Cloudflare/AWS addresses rotate; these would fail within days. |
| in-cluster pod IP | `namespaceSelector` / `podSelector` | pod IPs are ephemeral by definition |
| the DNS name from `policyRef` | a comment on the rule | provenance — so the next person knows *why* the rule exists |

**Read the generated policies as evidence, never as output.** Applied raw they
would be worse than what you have.

**1.4 — Commit the model.** A single file listing every off-cluster host, its
address, its VLAN, and the flows that reach it. Both the netpol generator and
the UniFi rules read from this. Today that inventory is:

| Host | Address | VLAN | Reached by |
|---|---|---|---|
| Obsidian REST API | 10.85.10.229 | Main (10) | 11 namespaces, :27124 |
| ms1/ms2/ms3 (Ollama) | 10.85.30.15/.20/.185 | Servers (30) | 4 namespaces, :11434 |
| UGREEN NAS | 10.85.30.127 | Servers (30) | NFS |
| 6 k8s nodes | 10.85.30.x | Servers (30) | intra-VLAN |
| Home Assistant | 10.85.40.102 | **IoT (40)** | → cluster :30080 |
| UNAS Pro | 10.85.0.168 | Default (1) | UNVR |

**Exit criteria:** generator produces a policy for a chosen namespace that a
human agrees with, and the model file is committed.

---

## Stage 2 — CNI decision: **RESOLVED — stay on flannel**

Decided 2026-08-18. The generator emits standard `NetworkPolicy` with subnets.
Stage 3 is unblocked.

The question was narrow: **230 observed flows are known by hostname, and plain
NetworkPolicy cannot express a hostname.** Three findings closed it.

**Calico cannot solve it at all.** DNS/FQDN policy is a Calico *Enterprise*
feature. The open-source version would not deliver the one capability that
motivated the question.

**Cilium can, but a migration would silently break an existing policy — and we
can name it.** Cilium's `ipBlock` rules do **not** match intra-cluster IPs
(pod/node) by default, whereas k3s's kube-router does today.
`apps/base/dji-media/networkpolicy.yaml` exists *precisely* to admit node IPs —
its own comment says "the only ingress we need to allow is from the cluster
nodes themselves so kubelet health probes can reach /healthz", implemented as
`ipBlock: 10.85.30.0/24`, which is the node subnet. Under Cilium's default that
rule stops matching, kubelet probes are denied, and dji-media CrashLoopBackOffs
— while the policy file still reads as correct.

That is the same silent-failure class that started this investigation.

And the fix has a sting: `policyCIDRMatchMode: nodes` is the same knob that
regressed `0.0.0.0/0` handling in cilium#39656. **9 of the 14 policies here use
`0.0.0.0/0`** for public-HTTPS egress — exactly the intersection that broke.

**The problem was never at the CNI layer.** Verified from inside a running
`oura-collector` pod: the app targets
`https://obsidian-api.landryzetam.net:27124` and DNS resolves correctly to the
current address. The clients re-resolve properly. **Only the policy layer was
ever broken** — so an FQDN-capable CNI would fix something that is not the
fault.

The real fixes are cheap: a **DHCP reservation** for the vault host, and
**freshness watchdogs** (Stage 0.6). Hours of work, versus a multi-day,
k3s-unsupported migration that has already been abandoned twice here.

If FQDN policy is ever genuinely wanted, `fqdn-controller` provides it without
touching the CNI, and Retina provides flow observability the same way.

---

## Stage 2b — Keeping topology out of a public repo

This repo is **public**, on a personal account, with 6,428 active code-scanning
alerts. Netpols need CIDRs, Flux needs to read the manifests, so the naive
answer is "commit the CIDRs" — which publishes the VLAN layout.

**SOPS-everywhere is the wrong tool here**, despite being the documented pattern
for secrets. Encrypting one allowlist (pv-browser) is fine. Encrypting ~50
policy files means every one becomes an opaque blob: diffs unreadable, review
impossible, and `grep` useless for answering "what can reach postgres?" It puts
heavy recurring friction on the file you most want to read and change, in order
to protect a low-sensitivity value (an RFC1918 subnet).

Three real options were considered:

| Option | Effect | Cost |
|---|---|---|
| **Make the repo private** | Total fix, nothing to mask | **Loses code scanning.** On a personal private repo it requires paid GitHub Advanced Security, so Trivy/Gitleaks SARIF upload and CodeQL all stop. 6,428 alerts of reporting surface. |
| **Second private repo, Flux reads both** | Works — Flux supports multiple `GitRepository` sources natively | Two repos to keep in sync, two review flows |
| **Remove the need for CIDRs** ← chosen | Netpols reference a label, not a subnet | One new component to run |

### Rejected: Flux postBuild variable substitution

Investigated and abandoned 2026-08-18. It looked like the clean answer — keep
`${VAULT_SUBNET}` in Git, supply the real value from a Secret at reconcile time —
and it is unsafe on this repo.

`postBuild.substituteFrom` rewrites **every** `${VAR}` pattern in every manifest
of the Kustomization, and undefined variables become an **empty string,
silently**. kustomize-controller here runs with no feature-gates, so
`StrictPostBuildSubstitutions` is off and nothing errors.

**37 manifests under `apps/` contain shell-style `${VAR}`; none carry the
`kustomize.toolkit.fluxcd.io/substitute: disabled` annotation.** The worst case
is not a broken script:

```bash
# backup-schedule.yaml, as written
find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
# after substitution
find ""              -mindepth 1 -maxdepth 1 -type d -mtime +          -exec rm -rf {} \;
```

Annotating all 37 would work but leaves a permanent trap: every future manifest
with a shell variable corrupts silently unless someone remembers.

Worth noting the goal was unreachable anyway. `substituteFrom` requires the
Secret in the Kustomization's own namespace (`flux-system`), and creating it
there with an ExternalSecret needs `aws-credentials` in `flux-system` — which is
SOPS-encrypted in all 24 namespaces that have it. **There is no SOPS-free path.**

### What remains exposed, and the honest options

Two CIDR rules, both deliberate:

| File | CIDR | What it is |
|---|---|---|
| `vault-gateway/networkpolicy.yaml` | `10.85.10.0/24` | client VLAN — the one worth hiding |
| `dji-media/networkpolicy.yaml` | `10.85.30.0/24` | node subnet; plain NetworkPolicy cannot express "the nodes" any other way |

Options, none free:

1. **Accept it.** Two RFC1918 ranges, one of which is the cluster's own subnet.
2. **Make the repo private.** Total fix; costs code scanning (personal private
   repos need paid GitHub Advanced Security), so Trivy SARIF, Gitleaks and
   CodeQL all stop. 6,428 alerts of reporting surface.
3. **A separate Flux Kustomization** for just those two files, with substitution
   enabled and the main `apps` Kustomization left alone. Avoids the footgun by
   scoping it, at the cost of a second Kustomization for two files.

Current recommendation: **(1)**, revisited if a third topology-carrying rule ever
appears. The vault gateway already removed the eleven that mattered.

### The chosen approach: an egress gateway for the vault

The only genuinely revealing CIDR is `10.85.10.0/24` — the client VLAN — and
**11 namespaces** need it, purely to reach the Obsidian API.

Put a reverse proxy in front of it, in-cluster:

- All 11 policies become `to: podSelector: {app: vault-gateway}` — a **label**.
  Zero topology in any of them.
- **One** manifest holds the real address. Encrypting a single value is
  tolerable where encrypting 50 files is not; it can equally live in a private
  repo or come from an ExternalSecret.
- When DHCP moves the vault, one file changes instead of eleven — which is the
  root cause of every incident in this family.
- It also retires `OBSIDIAN_VERIFY_TLS=false`, since the proxy can terminate
  properly and only the single hop to the plugin skips verification.

**This is already the repo's own documented plan.** `CLAUDE.md` says the TLS
workaround should be revisited "if the vault host moves off-LAN, the LAN admits
untrusted devices, or a 6th+ consumer is added — at which point an in-cluster
reverse proxy becomes worth the cost." There are 11 consumers. The threshold
was passed some time ago.

What remains in the clear afterwards is deliberately uninteresting:
`10.85.30.0/24` (the cluster's own subnet, which any node listing reveals) and
`0.0.0.0/0` minus RFC1918 (reveals nothing).

---

## Stage 3 — East-west enforcement (in-cluster)

Roll out generated policies namespace by namespace. Order by blast radius, not
by value.

1. Namespaces with no dependents and no inbound traffic (collectors, one-shot
   jobs) — `withings-collector`, `remarkable-ocr`, `dji-media`.
2. Namespaces already carrying a hand-written policy — replace with the
   generated-and-transformed one and diff the behaviour. These are the safest
   because you already know what they need.
3. Shared infrastructure — `postgres`, `keycloak`, `apisix`. Last, because
   everything depends on them.

**Per namespace:** apply, then exercise the app's real path and read its logs.
Never conclude from `kubectl get netpol` that a policy is correct.

**Remember the failure signature:** on this cluster a policy denial arrives at
the application as `Connection refused`, not a timeout, because enforcement
rejects rather than drops. When something breaks after a rollout, suspect the
policy first even though the error blames the remote service.

---

## Stage 4 — North-south enforcement (UniFi)

Already written in full: **`docs/operations/unifi-firewall-plan.md`**.

Its Phase 0 starts back in Stage 1.2. The enforcement phases (Guest → Cameras →
IoT → default-deny) run after Stage 3, so that if something breaks you are not
debugging two enforcement layers at once.

The single most important constraint, repeated here because it is the thing most
likely to cause an outage: **Home Assistant is at 10.85.40.102, inside the IoT
VLAN**, and it drives the cluster's voice pipeline. Give it a DHCP reservation
before any IoT rule is written.

---

## Stage 5 — Close the remaining gaps

- **Host OS package CVEs on the 6 Ubuntu nodes.** Nothing tracks these today —
  `kube-bench` checks host *configuration*, not patches. This is the one real
  gap a commercial tool (Qualys VMDR) would fill, and `unattended-upgrades` or a
  Trivy rootfs CronJob closes it for free.
- Anything the widened observation window surfaced that the 24h window missed.

---

## What this programme deliberately does not do

- **It does not buy Aqua or Qualys.** Aqua's published listings are
  $50k–$150k/yr and it is not sold to individuals; Qualys TotalCloud is $5,400/yr
  minimum and its free container tier withholds vulnerability data. Trivy —
  already in CI — *is* Aqua's scanner. The one capability neither OSS tool
  replicates is runtime *enforcement* and virtual patching, which solves a
  problem this homelab does not have: you own and can rebuild every image.
- **It does not SOPS-encrypt topology as a strategy.** Encrypting CIDRs treats
  the symptom. Policies derived from observed traffic and expressed as subnets
  or hostnames leave far less topology in manifests to hide. Keep SOPS for the
  handful of genuinely sensitive allowlists.
- **It does not add Falco.** It would be a second eBPF DaemonSet instrumenting
  the same syscalls as the node-agent already running, on nodes as small as 8GB.
  Revisit only if Kubescape's rule catalogue proves thin.

---

## Order of value, if you only do part of it

**Do 0.6 first, even before the rest of Stage 0.** A DHCP reservation and a
freshness alert are a couple of hours of work, and they convert the recurring
failure in this cluster from "silent for a month" to "paged in minutes" —
regardless of cause. Every other item reduces the probability of an outage;
this one bounds its duration. That is the better trade when the same class of
incident has now happened three times.

**Then the rest of Stage 0.** It recovers protection you already own and have
already paid for — runtime detection switched off, alerting degraded by a
crash-looping exporter, and a ghost-CRD trap that has already caused one outage
and is still armed. No design decisions, almost no risk.

**Stage 1 is the keystone.** Without a committed traffic model, Stages 3 and 4
degrade back into hand-writing rules and guessing — which is how the `/32` pins
got there in the first place.

**And note what Stage 2 concluded:** the CNI migration that looked like the
centrepiece of this work is now explicitly *not* being done. The evidence said
the fault was never at the CNI layer, and that migrating would have broken a
working policy in exactly the silent way that caused the original incident. That
removes the largest and riskiest item from the programme.
