#!/usr/bin/env python3
"""Join `du` output from the pv-catalog Job against live PersistentVolume objects.

Produces the table that answers: which of the Released PVs are empty shells safe
to reap, and which still hold data?

Usage:
    python3 join-catalog.py                 # human table
    python3 join-catalog.py --csv out.csv   # also write CSV
"""
import argparse
import datetime
import json
import subprocess
import sys

NS = "pv-catalog"
JOB = "job/pv-catalog"


def sh(*args: str) -> str:
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"command failed: {' '.join(args)}\n{r.stderr.strip()}")
    return r.stdout


def gib(cap: str) -> float:
    """Parse a Kubernetes quantity into GiB."""
    units = {"Ki": 1 / 1048576, "Mi": 1 / 1024, "Gi": 1, "Ti": 1024,
             "K": 1 / 1048576, "M": 1 / 1074, "G": 0.931, "T": 953}
    for suffix, mult in sorted(units.items(), key=lambda kv: -len(kv[0])):
        if cap.endswith(suffix):
            try:
                return float(cap[: -len(suffix)]) * mult
            except ValueError:
                return 0.0
    try:
        return float(cap) / 1024**3
    except ValueError:
        return 0.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", help="also write the full table to this CSV path")
    args = ap.parse_args()

    raw = sh("kubectl", "logs", "-n", NS, JOB)
    if "CATALOG_COMPLETE" not in raw:
        sys.exit(
            "Job output has no CATALOG_COMPLETE sentinel — it is still running or "
            "died partway. Refusing to report partial sizes as if they were whole."
        )

    sizes: dict[str, tuple[str, str, int]] = {}
    missing_shares: list[str] = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) != 4:
            continue
        share, name, kb, mt = parts
        if share == "MISSING":
            missing_shares.append(name)
            continue
        sizes[name] = (share, kb, int(mt))

    if missing_shares:
        print(f"WARNING: these shares did not mount: {', '.join(missing_shares)}\n")

    # Shares this pass actually mounted. A PV whose share is in here but whose
    # directory produced no row has no backing directory left on disk.
    MOUNTED = {"/volume1/k8s-storage", "/volume1/k8s-db",
               "/volume1/k8s-pg", "/volume1/k8s-backups"}
    MOUNTED_SERVER = "ugnas.landryzetam.net"
    CATALOG_OWN = {"catalog-k8s-storage", "catalog-k8s-db",
                   "catalog-k8s-pg", "catalog-k8s-backups"}

    pvs = json.loads(sh("kubectl", "get", "pv", "-o", "json"))["items"]

    rows = []
    for pv in pvs:
        name = pv["metadata"]["name"]
        claim = pv["spec"].get("claimRef") or {}
        share, kb, mt = sizes.get(name, ("-", None, 0))
        csi = pv["spec"].get("csi") or {}
        va = csi.get("volumeAttributes") or {}
        on_mounted_share = (va.get("server") == MOUNTED_SERVER
                            and va.get("share") in MOUNTED
                            and name not in CATALOG_OWN)
        if kb is None and on_mounted_share:
            # Its share was mounted and walked, yet no directory bearing this
            # PV's name exists -> the backing directory is already gone.
            actual = "GONE"
        elif kb is None:
            actual = None          # not covered by this pass
        elif kb in ("ERR", "SLOW"):  # noqa: E501
            # ERR  = unreadable; SLOW = too large to walk inside the timeout.
            # Neither is ever treated as empty, so neither can be reaped by
            # mistake off the back of this report.
            actual = kb
        else:
            actual = int(kb) / 1024  # MiB
        rows.append({
            "pv": name,
            "phase": pv["status"]["phase"],
            "claim": f'{claim.get("namespace", "-")}/{claim.get("name", "-")}',
            "claimed_gib": gib(pv["spec"]["capacity"]["storage"]),
            "claimed": pv["spec"]["capacity"]["storage"],
            "actual_mib": actual,
            "mtime": datetime.date.fromtimestamp(mt).isoformat() if mt else "-",
            "share": share,
            "sc": pv["spec"].get("storageClassName") or "-",
        })

    def sort_key(r):
        # Released first (that's the actionable set), then biggest real data first.
        a = r["actual_mib"]
        n = a if isinstance(a, float) else -1
        return (r["phase"] != "Released", -n)

    rows.sort(key=sort_key)

    hdr = f'{"PV":<44} {"PHASE":<9} {"CLAIM":<42} {"CLAIMED":>8} {"ACTUAL":>11}  MTIME'
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        a = r["actual_mib"]
        if a is None:
            shown = "unmeasured"
        elif isinstance(a, str):
            shown = a
        elif a >= 1024:
            shown = f"{a/1024:.1f}G"
        else:
            shown = f"{a:.0f}M"
        print(f'{r["pv"]:<44} {r["phase"]:<9} {r["claim"]:<42} '
              f'{r["claimed"]:>8} {shown:>11}  {r["mtime"]}')

    measured = [r for r in rows if isinstance(r["actual_mib"], float)]
    released = [r for r in rows if r["phase"] == "Released"]
    rel_meas = [r for r in released if isinstance(r["actual_mib"], float)]
    empty = [r for r in rel_meas if r["actual_mib"] < 1]
    holding = [r for r in rel_meas if r["actual_mib"] >= 1]
    errs = [r for r in rows if r["actual_mib"] == "ERR"]
    slow = [r for r in rows if r["actual_mib"] == "SLOW"]
    gone = [r for r in rows if r["actual_mib"] == "GONE"]
    gone_released = [r for r in gone if r["phase"] == "Released"]
    unmeasured = [r for r in rows if r["actual_mib"] is None]

    real_gib = sum(r["actual_mib"] for r in measured) / 1024
    claimed_gib = sum(r["claimed_gib"] for r in measured)

    print()
    print(f'PVs total .................... {len(rows)}')
    print(f'  measured ................... {len(measured)}')
    print(f'  unreadable (ERR) ........... {len(errs)}')
    print(f'  too large to walk (SLOW) ... {len(slow)}')
    print(f'  backing dir already gone ... {len(gone)}')
    print(f'  unmeasured (node-local/off-server) {len(unmeasured)}')
    print()
    print(f'Released total ............... {len(released)}')
    print(f'  effectively empty (<1MiB) .. {len(empty)}   <-- safe to reap')
    print(f'  backing dir gone ........... {len(gone_released)}   <-- safe to reap')
    print(f'  still holding data ......... {len(holding)}')
    print(f'  TOTAL definitively reapable  {len(empty) + len(gone_released)}')
    print()
    print(f'Claimed vs real (measured PVs): {claimed_gib:,.0f} GiB claimed '
          f'vs {real_gib:,.1f} GiB actual')

    if holding:
        print("\nLargest Released volumes still holding data:")
        for r in sorted(holding, key=lambda x: -x["actual_mib"])[:15]:
            a = r["actual_mib"]
            shown = f"{a/1024:.1f}G" if a >= 1024 else f"{a:.0f}M"
            print(f'  {shown:>9}  {r["claim"]:<42} {r["pv"]}  (mtime {r["mtime"]})')

    if args.csv:
        import csv
        with open(args.csv, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print(f"\nCSV written to {args.csv}")


if __name__ == "__main__":
    main()
