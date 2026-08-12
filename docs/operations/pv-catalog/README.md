# PV catalog

Measures the **actual bytes** behind every NFS-backed PersistentVolume, so you can
tell which orphaned volumes are empty shells and which still hold data.

## Why

`kubectl get pv` shows the capacity someone typed into a manifest. For thin NFS
volumes that number is fiction — a 200Gi PV may hold 40Gi or nothing at all. As of
2026-08-11 the cluster had **331 PVs, 275 of them Released** (orphaned, `Retain`,
still occupying whatever they occupy). There is no API that answers "how much is
actually in there"; you have to read the disk.

## How it works

Every dynamically-provisioned `nfs.csi.k8s.io` PV is a subdirectory named after
itself under one of four parent shares on `ugnas.landryzetam.net`. Verified: **309 of 309
PVs have `volumeAttributes.subdir == metadata.name`**. So mounting the four
*parent* shares in a single pod and running `du -sk` on each child measures 309 of
331 PVs in one pass — no per-volume mounting.

| share | PVs |
|---|---|
| `/volume1/k8s-storage` | 268 |
| `/volume1/k8s-db` | 25 |
| `/volume1/k8s-pg` | 13 |
| `/volume1/k8s-backups` | 3 |

The mount goes through the **CSI driver**, not an in-tree `nfs:` volume. Only
pglenovo01 has `/sbin/mount.nfs`; an in-tree mount would hang in
ContainerCreating on any other node. `csi-nfs-node` runs on all 5 nodes and ships
its own mount helper.

### Not covered (22 PVs, reported as `unmeasured`)

- **9 node-local on aitower** (`local-path`) — unreadable until that node
  returns. The other 8 live-node local PVs are now covered by
  `catalog-local-pvs.yaml` (second pass, measured 2026-08-11: 30.25 GiB total,
  of which 30.2 GiB is a single volume, `ai-content-studio/…-clips` on pgmac01).
- **3 off-server** — unas `Journals`, unas `SocialMedia`, ugnas `k8s-backups`.

## Safety

Read-only three ways: `ReadOnlyMany` PVs, the `ro` NFS mount option, and
`readOnly: true` on every container mount. The Job runs only `du` and `stat`.
All four PVs are `reclaimPolicy: Retain`, so deleting these objects afterwards
touches no data.

An unreadable directory reports `ERR`, never `0` — an unreadable volume must not
be mistaken for an empty one and reaped.

This is a hand-applied one-off. It lives outside every Flux reconcile path and
**must never be added to one**.

## Run it

```bash
kubectl apply -f catalog-pvs.yaml
kubectl wait --for=condition=complete job/pv-catalog -n pv-catalog --timeout=90m
python3 join-catalog.py | tee ~/pv-catalog-$(date +%F).txt
python3 join-catalog.py --csv ~/pv-catalog-$(date +%F).csv   # optional

kubectl delete -f catalog-pvs.yaml
```

`du` over ~7TB of NFSv3 is the slow part. Measured run: **9 minutes**, because
each directory is bounded by `PER_DIR_TIMEOUT` (default 120s). Without that bound
a single chunk store — `loki-stack/storage-loki-0` — held the walk for over 14
minutes on its own and would have consumed the whole Job deadline, returning no
catalog at all. Volumes that exceed the bound report `SLOW` and the run moves on.

`join-catalog.py` refuses to print if the Job's `CATALOG_COMPLETE` sentinel is
missing, so a partial run can't be mistaken for a full one.

## Output

Per PV: name, phase, the claim it belonged to, claimed size, **actual size**, and
directory mtime. Sizes that are not a number carry meaning:

| value | meaning |
|---|---|
| `GONE` | share was mounted and walked, but no directory of that name exists — the PV is a tombstone, safe to reap |
| `SLOW` | exceeded `PER_DIR_TIMEOUT`; readable but too large to walk. **Never** treated as empty |
| `ERR` | unreadable. **Never** treated as empty |
| `unmeasured` | node-local or off-server; not covered by this pass |

The table is — sorted Released-first, biggest-real-data-first. Then a summary
splitting Released volumes into "effectively empty (<1MiB), safe to reap" versus
"still holding data", and a claimed-vs-real total.

It also settles which of the fifteen 200Gi `ollama/ollama-models` volumes is the
real one before you re-enable the GPU stack.

## Caveats

- **mtime is the directory's**, not the newest file inside it. Walking every file
  across 7TB would take far longer. Good staleness proxy, not proof.
- The pod runs as **root** (namespace is PSS `baseline`) so `du` can traverse
  directories owned by arbitrary UIDs. Without it much of the catalog returns
  `ERR`. Mounts are read-only regardless.
