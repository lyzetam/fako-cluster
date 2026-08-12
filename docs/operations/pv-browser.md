# PV Browser

Read-only web UI over every NFS-backed PersistentVolume in the cluster.

**https://pv-browser.landryzetam.net** — home network only.

## Why

`kubectl get pv` reports the capacity someone typed into a manifest, which for
thin NFS volumes is fiction. Answering "what is actually in this volume" used to
mean SSHing to the NAS and walking directories by hand. This gives a tree, file
sizes, modified times, search, preview and download.

Pairs with `docs/operations/pv-catalog/`, which measures **actual bytes** per PV
and joins them to their owning claim. The catalog answers "how big, and is it an
orphan"; the browser answers "what is in it".

## What it is

[filebrowser](https://github.com/filebrowser/filebrowser) v2.63.23 — upstream
open source, Apache 2.0. Nothing here is bespoke except the Kubernetes wiring in
`apps/base/pv-browser/`.

All 309 NFS PVs appear as directories under four parent shares:

| mount | PVs |
|---|---|
| `/srv/k8s-storage` | 268 |
| `/srv/k8s-db` | 25 |
| `/srv/k8s-pg` | 13 |
| `/srv/k8s-backups` | 3 |

Directories are named `pvc-<uuid>`. To map one to its owner:

```bash
kubectl get pv <name> -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}'
```

## Credentials

```bash
sops -d apps/staging/pv-browser/admin-secret.yaml
```

Username `admin`. Rotate by editing that file with `sops` and restarting the
deployment — the init container re-applies the password on every start.

## Security

**Read-only, four independent layers.** `ReadOnlyMany` PVs; `ro` in
`mountOptions`; `readOnly: true` on every container mount; filebrowser perms with
create/delete/rename/modify all false, re-applied by the init container on each
start so a UI change cannot persist. Verified: `touch` inside the pod returns
`Read-only file system`.

**Home network only, enforced.** A traefik `ipAllowList` middleware 403s any
source outside the allowed ranges. Verified in both directions — 200 from the
LAN, 403 from a source outside the list, which also proves traefik sees the real
client IP rather than a SNAT'd node address. Ranges are SOPS-encrypted in
`apps/staging/pv-browser/lan-only-middleware.yaml`; plaintext reference in
`private/pv-browser.md`.

DNS resolves to a private address, so it is unreachable from the internet before
the allowlist even applies. TLS via `letsencrypt-dns01` — an HTTP-01 issuer can
never work here, because Let's Encrypt cannot reach a private address.

**Pod is constrained.** `restricted` PSS, non-root UID 1000, no privilege
escalation, all capabilities dropped, `RuntimeDefault` seccomp, 256Mi/0.5cpu cap.

## Known limits

- One shared admin account — no per-user identity, MFA or audit trail. Putting it
  behind Keycloak via oauth2-proxy (the `oura-dashboard` pattern) is the obvious
  upgrade.
- It aggregates everything, database directories included. Read-only limits this
  to disclosure rather than damage, but that is still one credential over the lot.
- LAN-only is a perimeter control. It does not defend against something already
  on the network.
