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
itself under one of four parent shares on `10.85.30.127`. Verified: **309 of 309
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

- **17 node-local** (`local-path`) — 9 stranded on the dead aitower, 8 on live
  nodes. The live ones need a second pass: a DaemonSet reading
  `/var/lib/rancher/k3s/storage` on each node.
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

`du` over ~7TB of NFSv3 is the slow part. Budget 30–90 minutes, not 10. The Job
has `activeDeadlineSeconds: 5400`.

`join-catalog.py` refuses to print if the Job's `CATALOG_COMPLETE` sentinel is
missing, so a partial run can't be mistaken for a full one.

## Output

Per PV: name, phase, the claim it belonged to, claimed size, **actual size**, and
directory mtime — sorted Released-first, biggest-real-data-first. Then a summary
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
