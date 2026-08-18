# UniFi firewall — staged implementation plan

Status: **draft, nothing applied.** Every phase below is written to be executed
one at a time, verified, and rolled back independently.

Gateway: Archer Core UDM (UDM SE), Network 10.5.67, zone-based Policy Engine.

---

## 1. Where you are today (measured 2026-08-18)

Ten networks, **all ten in a single `Internal` zone**, and the zone matrix says
`Internal → Internal = Allow All`.

| Network | VLAN | Subnet | DHCP leases |
|---|---|---|---|
| Default | 1 | 10.85.0.0/24 | 17 |
| Main | 10 | 10.85.10.0/24 | 40 |
| Security | 20 | 10.85.20.0/24 | 16 |
| Servers | 30 | 10.85.30.0/24 | 11 |
| Clusters | 35 | 10.85.35.0/24 | 4 |
| IoT | 40 | 10.85.40.0/24 | **74** |
| Guest | 50 | 10.85.50.0/24 | 9 |
| Work | 60 | 10.85.60.0/24 | 6 |
| Voice | 70 | 10.85.70.0/24 | 0 |
| GPU Farm | 2 | 192.168.3.0/24 | 0 |

There are **4 custom firewall policies and all four are `Allow`** — they permit
traffic the zone default already permits, so removing them would change nothing.
There are **0 port forwards, 0 ACL rules, 0 policy-based routes**.

**Inbound from the internet is already in good shape.** `External → Internal` is
`Allow Return` only, and with no port forwards there is no unsolicited path in.
External access arrives through Cloudflare Tunnels, which are outbound
connections. This plan does not need to change anything about inbound.

**The gap is lateral.** 74 IoT devices, 9 guest devices and 16 cameras can all
reach the Kubernetes cluster, the NAS, and each other, because they are all in
one zone with Allow All between members.

---

## 2. What actually needs to cross VLANs

This is the part that makes the plan safe, and it is measured rather than
guessed. Sources: Kubescape's eBPF-derived `GeneratedNetworkPolicy` objects
(371 workload policies, 24h learning window), Kubernetes node/service
inventory, and DNS resolution of the known homelab hosts.

Key placements:

| Host | Address | VLAN |
|---|---|---|
| All 6 k8s nodes (+ Traefik LB) | 10.85.30.8/.99/.107/.126/.172/.214 | Servers (30) |
| UGREEN NAS (NFS to cluster) | 10.85.30.127 | Servers (30) |
| Ollama Mac Studios ms1/ms2/ms3 | 10.85.30.15/.20/.185 | Servers (30) |
| mm1 (Obsidian vault API host) | 10.85.30.29 | Servers (30) |
| Obsidian Local REST API | 10.85.10.229 | **Main (10)** |
| **Home Assistant** | **10.85.40.102** | **IoT (40)** |
| UNAS Pro | 10.85.0.168 | Default (1) |

Required cross-VLAN flows, with the evidence for each:

| # | Flow | Port | Why / evidence |
|---|---|---|---|
| F1 | Servers(30) → Main(10) | TCP 27124 | Cluster writes to the Obsidian vault. **11 namespaces** depend on it (oura-collector, fieldy-webhook, hume-collector, plaud-collector, remarkable-ocr, kube-bench, …). Breaking this is what caused the 2026-08-18 vault outage. |
| F2 | IoT(40) → Servers(30) | TCP 30080 | Home Assistant → `voice-ingest` NodePort. The on-prem voice pipeline. |
| F3 | Main(10) → Servers(30) | TCP 80, 443 | You browsing the homelab web apps via Traefik. |
| F4 | Main(10) → Servers(30) | TCP 6443, 22 | `kubectl` and SSH administration from your laptop. |
| F5 | Security(20) → Default(1) | camera/NVR | UNVR → UNAS Pro (10.85.0.168). An explicit rule already exists for this. |
| F6 | Any → Gateway | UDP 53, 67 | DNS and DHCP. UniFi's built-in policies already cover this. |
| F7 | All → External | 443 etc. | Internet. Already `Allow All`. |

Everything the **cluster** reaches off-VLAN is just F1 — everything else it talks
to (NAS, Ollama, other nodes) is inside Servers(30), so it never touches a
firewall rule. That is why this is tractable.

### Known gaps in the evidence — resolve in Phase 0

- The Kubescape learning window is **24 hours**. A weekly or monthly CronJob's
  traffic will not appear in it. Phase 0 exists to catch those.
- Whether Home Assistant calls Ollama (11434) or Whisper/Piper directly, in
  addition to F2.
- What the 4 devices on Clusters(35) and 16 on Security(20) actually talk to.
- Whether any IoT device needs to reach anything besides Home Assistant and the
  internet (printers and Chromecast-style devices often need mDNS from Main).

---

## 3. Target posture

Move from "one big Internal zone, allow all" to per-purpose zones with a default
of block between them, plus the small explicit allow-list above.

| Proposed zone | Networks | Default to other zones |
|---|---|---|
| `Trusted` | Main(10), Work(60) | allow out to Servers/IoT; block from Guest |
| `Infra` | Servers(30), Clusters(35), Default(1) | accept F1..F4; no initiation into IoT/Guest |
| `IoT` | IoT(40), Voice(70) | internet + Home Assistant only |
| `Cameras` | Security(20) | NVR/NAS only, **no internet** |
| `Guest` | Guest(50) | internet only, nothing internal |
| `Quarantine` | GPU Farm(2) | already blocked; keep |

This is the destination, not the first step. The phases below get there in an
order chosen so that the risky changes come last and each one is independently
reversible.

---

## 4. Execution phases

Rule for every phase: **one phase per sitting.** Apply, verify, then live with it
for at least 24 hours before starting the next. Note the time you applied it —
if something breaks two days later, you need to know which change to suspect.

Universal rollback: UniFi keeps each policy as a discrete object. Rolling back is
setting the policy back to `Allow` or toggling it off — it is not a restore.
Take a screenshot of the Policy Table before each phase.

---

### Phase 0 — See the traffic before you block it (no enforcement)

**Risk: none.** Nothing is blocked in this phase.

1. Policy Engine → Policy Table → for the zone pairs you intend to restrict,
   create `Allow` rules with **logging enabled** rather than block rules.
2. Leave them for **7 days**, so weekly CronJobs and rarely-used devices appear.
3. Review the logs and reconcile against the F1–F7 table above. Anything that
   shows up and is not in that table is either a flow to add, or the first thing
   your block rules will correctly stop.

Do not skip this. The measured flow table is a 24-hour snapshot; this phase is
what turns it into a week.

**Verify:** log entries are appearing for known-good traffic (browse a homelab
app, trigger a voice command).

---

### Phase 1 — Fence the empty and unused networks

**Risk: effectively zero — these networks have 0 DHCP leases.**

- Voice(70): 0 devices. GPU Farm(2): 0 devices (and already covered by the
  existing `Isolated Networks` block for 192.168.3.0/24).

1. Create zone `Quarantine`; move GPU Farm(2) into it.
2. Set `Quarantine → *` = Block All, `* → Quarantine` = Block All.
3. Leave Voice(70) where it is for now — it is empty, so it is not a risk, and
   moving it costs nothing to defer.

**Verify:** nothing to verify; nothing was using these.
**Rollback:** move the network back to Internal.

---

### Phase 2 — Guest isolation

**Risk: low.** Affects 9 devices, none of which should ever reach anything
internal. This is the highest security value for the least chance of breaking
something you care about.

1. Create zone `Guest`.
2. Move network Guest(50) into it.
3. Zone matrix:
   - `Guest → External` = **Allow All** (internet works)
   - `Guest → Internal` = **Block All**
   - `Guest → Gateway` = allow **UDP 53, 67 only** (DNS + DHCP — without this,
     guest devices get no address and no name resolution, and it will look like
     the internet is broken)
   - `Internal → Guest` = Block All
4. If you use a Guest WiFi portal, confirm it still loads.

**Verify:** join the guest SSID on a phone; confirm the internet works and that
`http://10.85.30.214` (a cluster node) does **not** load.
**Rollback:** move Guest(50) back into Internal.

**Known casualty:** casting from a guest device to a Main-VLAN TV stops working.
That is the intended behaviour, but decide now whether you care.

---

### Phase 3 — Camera containment

**Risk: low-moderate.** 16 devices. Cameras are a classic outbound-exfiltration
risk and generally need nothing but the NVR.

1. Create zone `Cameras`; move Security(20) into it.
2. Matrix:
   - `Cameras → Internal` = Block All, **except** an explicit allow to the NVR
     and to UNAS Pro (10.85.0.168) — the existing `UNVR to NAS` rule already
     encodes this pair, so reuse it.
   - `Cameras → External` = **Block All.** This is the valuable half: it stops a
     camera phoning home. Only add an allow if a specific camera needs cloud
     features you actually use.
   - `Internal → Cameras` = Allow from Main(10) only, so you can still open the
     camera UI and Protect app.

**Verify:** open UniFi Protect and confirm live view plus playback; confirm
recordings are still being written to the NVR.
**Rollback:** set `Cameras → External` back to Allow first — that is the rule
most likely to break a camera's firmware update or time sync.

**Watch for:** cameras that use NTP or a cloud relay will misbehave subtly (drifting
timestamps) rather than failing loudly. Check timestamps a day later.

---

### Phase 4 — IoT containment (the valuable one, and the one that bites)

**Risk: HIGH. 74 devices, and Home Assistant lives here.**

Home Assistant at 10.85.40.102 is *inside* IoT(40) but must reach the cluster
(F2) and controls devices across the network. A naive block breaks your
automations and the voice pipeline.

1. Create zone `IoT`; move IoT(40) into it.
2. Matrix:
   - `IoT → External` = Allow (many devices need cloud; tighten later per-device)
   - `IoT → Internal` = **Block All**
   - Then add explicit allows *above* the block:
     - **10.85.40.102 → 10.85.30.0/24 TCP 30080** (F2, Home Assistant → voice-ingest)
     - **10.85.40.102 → 10.85.30.0/24 TCP 11434** *only if* Phase 0 logging shows
       Home Assistant calling Ollama directly
   - `Main(10) → IoT` = Allow (so your phone can drive devices directly)
3. Consider giving Home Assistant a **static reservation** first, so the rule
   cannot be invalidated by a DHCP change. This is the same failure that broke
   the cluster's vault writes — a pinned address that moved.

**Verify, in this order:** Home Assistant UI loads; a light responds; a voice
command completes end-to-end (that exercises F2); then spot-check a few of the
74 devices — a smart plug, a TV, a printer.
**Rollback:** set `IoT → Internal` back to Allow All. Do this immediately if
voice or automations break; debug afterwards, not while the house is broken.

**Strongly recommended:** do this phase on a weekend morning, not at night, and
not while you are away from home.

---

### Phase 5 — Trusted / Infra split, and default-deny

**Risk: moderate.** Only attempt after Phases 1–4 have been stable for a week.

1. Create zones `Trusted` (Main, Work) and `Infra` (Servers, Clusters, Default).
2. Encode F1, F3, F4, F5 as explicit allows.
3. Flip `Infra → Trusted` to Block All **except F1** (Servers → Main :27124).
   F1 is the single flow the cluster genuinely needs outbound to another VLAN.
4. Only once that is stable, consider the global `Default Security Posture`
   toggle from Allow All to Block All.

**Verify:** the cluster's vault writes still succeed. The honest check is the
application, not a ping:

```bash
kubectl logs -n oura-collector deploy/oura-collector --tail=30 | grep -i obsidian
# expect no "Obsidian API save failed"

kubectl exec -n oura-collector deploy/oura-collector -- \
  python3 -c "import socket;s=socket.socket();s.settimeout(6);s.connect(('10.85.10.229',27124));print('OPEN')"
```

**Rollback:** revert the zone pair to Allow All.

---

## 5. Two traps specific to this network

**A denial here looks like a remote outage.** Both this gateway and the
cluster's own NetworkPolicy layer reject rather than drop, so a blocked
connection surfaces to the application as `Connection refused` — which reads as
"the far end is down", not "a policy stopped me". When something breaks after a
phase, suspect the firewall *first*, even though the error blames the service.
This is precisely what hid the 2026-08-18 vault outage.

**Pinned host addresses are the recurring failure.** `10.85.10.195` → `.229` on
2026-08-05 silently cost a week of vault writes, twice, in two different apps.
Any rule written against a single host address is a future outage unless that
host has a DHCP reservation. Prefer a subnet + port, or reserve the address
first.

---

## 6. Order of value

If you only ever do part of this: **Phase 2 (Guest) and Phase 3 (Cameras →
no internet) deliver most of the security benefit for a small fraction of the
risk.** Phase 4 is where the real exposure is — 74 devices — but it is also the
phase most likely to page you, so it deserves its own dedicated session.
