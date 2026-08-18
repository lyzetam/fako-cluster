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
| 0.1 | **Delete the Cilium wreckage** — leftover CRDs (2025-09-04) and the stale `cilium-operator-resource-lock` lease | This is the direct cause of the vault outage. While the CRDs exist, the API server accepts `CiliumNetworkPolicy` objects and nothing enforces them — a policy that *looks* applied and does nothing. It will happen again. | Low. Nothing consumes them; the two ghost policies are already deleted. |
| 0.2 | **Enable `runtimeDetection`** + raise node-agent memory | The node-agent already runs on every node and has built 371 ApplicationProfiles. The detection engine that consumes them is off — you pay the eBPF cost and get none of the detection. | Low, but **memory is the real risk**: one node-agent is at 872Mi against a 1400Mi limit. Raise the limit in the same commit. |
| 0.3 | **Fix kube-state-metrics** | It has restarted 4 times (most recent 4h ago, reason `Error`) and measured 74.8% scrape availability over 6h. *Every* KSM-based alert in the cluster is degraded, including the new backup alerts. | Low. Diagnostic first — find why it dies. |
| 0.4 | **Block egress to 169.254.169.254** | `family-manager` and `meal-tracker` reach for the cloud metadata endpoint — an AWS SDK hunting for instance credentials that do not exist on-prem. Harmless today, classic SSRF target. | Trivial. |
| 0.5 | **Set the three inert Kubescape capabilities to `disable`** | `httpDetection`, `networkEventsStreaming`, `nodeProfileService` are enabled but render false — the config claims coverage it does not deliver. | Trivial. |

**Exit criteria:** no Cilium CRDs in the cluster; runtime detection producing
alerts into Alertmanager; KSM stable for 24h.

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

## Stage 2 — CNI decision (one gate, decided once)

This gates the *output format* of the generator, which is why it sits between
building the generator and rolling it out.

The question is narrow and quantified: **230 of the observed flows are known by
hostname, and plain NetworkPolicy cannot express a hostname.** Everything else
about Cilium is secondary here.

- **Stay on flannel** → generator emits standard `NetworkPolicy` with subnets.
  The `/24` collapse already solves the DHCP brittleness, which is the actual
  pain. Zero migration risk.
- **Move to Cilium** → generator emits `CiliumNetworkPolicy` with `toFQDNs` for
  those 230 flows, plus Hubble gives continuous flow visibility instead of a
  learning window. But: k3s requires `--flannel-backend=none
  --disable-network-policy`, which is a re-provision of every node, and Cilium
  was already tried here once and abandoned with node-level iptables damage.

Migration risk assessment is in flight. **Do not start Stage 3 before this is
decided** — deciding late means rewriting the generator's output.

Default if the assessment is inconclusive: **stay on flannel.** The `/24`
collapse fixes the real-world failure, and a CNI migration is the highest-risk
action available in this cluster.

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

**Stage 0 alone** recovers protection you already own and have already paid for
— runtime detection off, alerting degraded, and a ghost-CRD trap that has
already caused one outage. It needs no design decisions and carries almost no
risk.

**Stage 1 is the keystone.** Without a committed traffic model, Stages 3 and 4
degrade back into hand-writing rules and guessing — which is how the `/32` pins
got there in the first place.
