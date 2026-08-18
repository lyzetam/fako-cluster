# UniFi firewall — staged implementation plan

**The plan itself lives in `private/unifi-firewall-plan.md`, which is
gitignored.** This file is a tracked pointer, not a summary with the details
filed off.

That split is deliberate and follows the rule in `CLAUDE.md`: values the cluster
must read get SOPS-encrypted into the overlay; *explanation of what sits where*
goes in `private/` and the tracked file carries a pointer, never the detail.

A firewall plan is almost entirely "what sits where" — VLAN numbers, subnets,
which host is on which segment, which flows cross which boundary. Scrubbing it
produced a document whose subnet column read "that VLAN" six times: useless to
work from, while still leaking the shape. Keeping it whole and private is the
honest version.

## What is safe to say here

- Ten networks currently share a single `Internal` zone, and that zone allows
  everything to everything. All the lateral exposure follows from that.
- Inbound is already sound: external-to-internal is return-traffic only and
  there are zero port forwards, because external access arrives via Cloudflare
  Tunnels, which are outbound connections.
- There are 4 custom firewall policies and all four are `Allow`, so they grant
  nothing the zone default did not already grant.
- The execution order is by blast radius, not by value: empty VLANs, then the
  guest network, then cameras, then IoT. IoT is last among the real ones because
  Home Assistant lives inside that segment and drives the cluster's voice
  pipeline, so a naive block takes out the automations.
- Two traps, both of which have already caused outages here: a denial on this
  network surfaces to applications as `Connection refused` and reads as a remote
  outage rather than a policy denial; and any rule pinned to a single host
  address breaks silently when DHCP moves it.

## Related

- `private/network-topology.md` — VLANs, host placements, required cross-VLAN flows
- `docs/operations/hardening-programme.md` — how this fits the wider sequence
