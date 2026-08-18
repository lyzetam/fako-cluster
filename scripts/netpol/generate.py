#!/usr/bin/env python3
"""
Turn Kubescape's traffic-derived GeneratedNetworkPolicy objects into
committable, non-brittle NetworkPolicy manifests.

Why this exists
---------------
Kubescape's node-agent observes real traffic via eBPF and emits one
GeneratedNetworkPolicy per workload. Those are excellent EVIDENCE and terrible
OUTPUT: measured 2026-08-18 across 371 of them, they carried 112 hardcoded /32
pins to LAN hosts and 2,281 to external hosts (one policy held 109).

  - A /32 to a LAN host breaks the moment DHCP moves it. That exact failure cost
    a week of vault writes, twice, in two different apps.
  - A /32 to Discord/Cloudflare/AWS breaks within days; those addresses rotate.
  - A /32 to a pod IP is meaningless — pod IPs are ephemeral by definition.

So this script keeps what the observation KNOWS (which host, which port, by
name) and discards how it happened to be addressed at that moment.

Usage
-----
    python3 scripts/netpol/generate.py --namespace withings-collector
    python3 scripts/netpol/generate.py --namespace withings-collector --write

Without --write it prints to stdout so the transform can be eyeballed first.
Always read the diff. This produces a STARTING POINT for a human, not a
manifest to apply unread.

Important
---------
Kubescape's storage strips `spec` from LIST queries at every level, so a
`kubectl get ... -A` returns objects with empty specs and this would silently
emit nothing. Each object must be fetched individually. That is why this walks
names and GETs one at a time rather than listing.
"""

import argparse
import ipaddress
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

# LAN subnets this cluster talks to, from the committed traffic model. A /32
# observed inside one of these is widened to the whole /24: the host is on a
# DHCP lease and its address is not a stable identifier.
LAN_SUBNETS = ["10.85.0.0/24", "10.85.10.0/24", "10.85.20.0/24", "10.85.30.0/24",
               "10.85.35.0/24", "10.85.40.0/24", "10.85.50.0/24", "10.85.60.0/24",
               "10.85.70.0/24", "192.168.3.0/24"]

# In-cluster ranges. A /32 here is a pod or service IP — ephemeral, never a
# valid policy target. These are dropped and reported, not emitted.
CLUSTER_RANGES = ["10.42.0.0/16", "10.43.0.0/16"]

# The repo's existing convention for "public internet, but never the LAN".
PUBLIC_EXCEPT = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]


def kubectl_json(args):
    out = subprocess.run(["kubectl", *args, "-o", "json"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return None
    return json.loads(out.stdout)


def fetch_generated(namespace):
    """GET each object individually — LIST strips the spec (see module docstring)."""
    listing = subprocess.run(
        ["kubectl", "get", "generatednetworkpolicies", "-n", namespace,
         "-o", "jsonpath={range .items[*]}{.metadata.name}{'\\n'}{end}"],
        capture_output=True, text=True)
    names = [n for n in listing.stdout.split("\n") if n.strip()]
    objs = []
    for n in names:
        o = kubectl_json(["get", "generatednetworkpolicies", "-n", namespace, n])
        if o and o.get("spec", {}).get("spec"):
            objs.append(o)
    return objs


def classify(cidr):
    """-> ('lan', '10.85.10.0/24') | ('cluster', None) | ('public', None) | ('other', cidr)"""
    try:
        net = ipaddress.ip_network(cidr, strict=False)
    except ValueError:
        return ("other", cidr)
    for r in CLUSTER_RANGES:
        if net.subnet_of(ipaddress.ip_network(r)):
            return ("cluster", None)
    for s in LAN_SUBNETS:
        if net.subnet_of(ipaddress.ip_network(s)):
            return ("lan", s)
    if net.num_addresses == 1 and not net.network_address.is_private:
        return ("public", None)
    if net.network_address.is_private:
        return ("other", cidr)
    return ("public", None)


def transform(objs):
    """Collapse observed egress into stable rules. Returns (rules, notes)."""
    dns_of = {}
    for o in objs:
        for ref in (o.get("policyRef") or []):
            ip = (ref.get("ipBlock") or "").split("/")[0]
            if ip and ref.get("dns"):
                dns_of[ip] = ref["dns"].rstrip(".")

    lan = defaultdict(lambda: defaultdict(set))   # subnet -> port -> {names}
    public = defaultdict(set)                     # port -> {names}
    selectors = {}                                # json(selector) -> {(port,proto)}
    dropped = defaultdict(set)

    for o in objs:
        for eg in (o["spec"]["spec"].get("egress") or []):
            ports = [(p.get("port"), p.get("protocol", "TCP"))
                     for p in (eg.get("ports") or [])]
            for to in (eg.get("to") or []):
                if "ipBlock" not in to:
                    # Keep the selector AND its ports. Dropping the ports here
                    # would silently widen e.g. "postgres:5432" into "postgres on
                    # every port" — a real bug caught in review of the first run.
                    key = json.dumps(to, sort_keys=True)
                    selectors.setdefault(key, set()).update(ports)
                    continue
                cidr = to["ipBlock"]["cidr"]
                ip = cidr.split("/")[0]
                name = dns_of.get(ip, ip)
                kind, subnet = classify(cidr)
                if kind == "cluster":
                    dropped["pod/service IP (ephemeral)"].add(name)
                elif kind == "lan":
                    for pt, _ in ports or [(None, "TCP")]:
                        lan[subnet][pt].add(name)
                elif kind == "public":
                    for pt, _ in ports or [(None, "TCP")]:
                        public[pt].add(name)
                else:
                    dropped["unclassified"].add(cidr)

    rules, notes = [], []
    for subnet in sorted(lan):
        for port in sorted(lan[subnet], key=lambda p: (p is None, p)):
            names = sorted(lan[subnet][port])
            rules.append({
                "_comment": f"{', '.join(names)} — LAN host(s). Scoped to the /24, "
                            f"not a /32: these are DHCP leases and a pinned address "
                            f"has already caused silent outages here.",
                "to": [{"ipBlock": {"cidr": subnet}}],
                "ports": [{"protocol": "TCP", "port": port}] if port else [],
            })
    for port in sorted(public, key=lambda p: (p is None, p)):
        names = sorted(public[port])
        shown = ", ".join(names[:6]) + (f", +{len(names)-6} more" if len(names) > 6 else "")
        rules.append({
            "_comment": f"Public internet on {port}: {shown}. Emitted as "
                        f"allow-public-minus-RFC1918 rather than {len(names)} pinned "
                        f"addresses, which rotate and would fail within days.",
            "to": [{"ipBlock": {"cidr": "0.0.0.0/0", "except": list(PUBLIC_EXCEPT)}}],
            "ports": [{"protocol": "TCP", "port": port}] if port else [],
        })
    for key in sorted(selectors):
        sel = json.loads(key)
        pts = sorted(selectors[key], key=lambda x: (x[0] is None, x[0]))
        label = ", ".join(f"{pr}/{pt}" for pt, pr in pts) or "all ports (none observed)"
        rules.append({
            "_comment": f"in-cluster, by selector — {label}. Selectors are kept "
                        f"verbatim: pod IPs churn, labels do not.",
            "to": [sel],
            "ports": [{"protocol": pr, "port": pt} for pt, pr in pts if pt],
        })
    for reason, items in dropped.items():
        notes.append(f"dropped {len(items)} target(s) — {reason}")
    return rules, notes


def render(namespace, app, rules, notes):
    L = []
    L.append(f"# {namespace} egress — DERIVED from observed traffic, then widened.")
    L.append("#")
    L.append("# Source: Kubescape GeneratedNetworkPolicy (eBPF observation).")
    L.append("# Generated by scripts/netpol/generate.py — REVIEW BEFORE APPLYING.")
    L.append("#")
    L.append("# The observation recorded exact addresses at one moment in time. Those")
    L.append("# have been widened to stable subnets, because pinning a DHCP address is")
    L.append("# what silently broke vault writes here twice. The hostnames in the")
    L.append("# comments below are the real provenance — keep them.")
    for n in notes:
        L.append(f"#   note: {n}")
    L.append("apiVersion: networking.k8s.io/v1")
    L.append("kind: NetworkPolicy")
    L.append("metadata:")
    L.append(f"  name: {app}-egress")
    L.append(f"  namespace: {namespace}")
    L.append("spec:")
    L.append("  podSelector: {}")
    L.append("  policyTypes:")
    L.append("    - Egress")
    L.append("  egress:")
    for r in rules:
        for i, line in enumerate(_wrap(r["_comment"], 72)):
            L.append(f"    # {line}")
        first = True
        for t in r["to"]:
            prefix = "    - to:" if first else None
            if first:
                L.append(prefix)
                first = False
            L.extend(_yaml_block(t, indent=8))
        if r["ports"]:
            L.append("      ports:")
            for p in r["ports"]:
                L.append(f"        - protocol: {p['protocol']}")
                L.append(f"          port: {p['port']}")
    return "\n".join(L) + "\n"


def _wrap(text, width):
    words, line, out = text.split(), "", []
    for w in words:
        if len(line) + len(w) + 1 > width:
            out.append(line); line = w
        else:
            line = f"{line} {w}".strip()
    if line:
        out.append(line)
    return out


def _yaml_block(obj, indent):
    """Minimal YAML emitter for the small, known shapes used here."""
    pad = " " * indent
    out = []
    for k, v in obj.items():
        if isinstance(v, dict):
            out.append(f"{pad}- {k}:" if not out else f"{pad}  {k}:")
            for k2, v2 in v.items():
                if isinstance(v2, list):
                    out.append(f"{pad}    {k2}:")
                    for item in v2:
                        out.append(f"{pad}      - {item}")
                else:
                    out.append(f"{pad}    {k2}: {v2}")
        else:
            out.append(f"{pad}- {k}: {v}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--namespace", required=True)
    ap.add_argument("--write", action="store_true",
                    help="write to apps/base/<ns>/networkpolicy-generated.yaml")
    a = ap.parse_args()

    objs = fetch_generated(a.namespace)
    if not objs:
        print(f"no GeneratedNetworkPolicy with a populated spec in {a.namespace}.\n"
              f"(If you expected some: LIST strips the spec — this script GETs each "
              f"object individually, so an empty result here is real.)", file=sys.stderr)
        sys.exit(1)

    app = objs[0]["metadata"]["labels"].get("kubescape.io/workload-name", a.namespace)
    rules, notes = transform(objs)
    text = render(a.namespace, app, rules, notes)

    if a.write:
        p = Path("apps/base") / a.namespace / "networkpolicy-generated.yaml"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        print(f"wrote {p}  ({len(rules)} rules from {len(objs)} observed policies)")
    else:
        print(text)


if __name__ == "__main__":
    main()
