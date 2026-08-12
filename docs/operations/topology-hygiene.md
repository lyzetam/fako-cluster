# Keeping network topology out of the manifests

Subnets, VLAN layout and device addresses must not sit in a committed manifest.
This repo is private, but a private repo is not a secret store, and an address
in a manifest outlives the address itself.

Pick the mechanism by asking whether the **cluster** needs the value.

## 1. Prefer DNS

`ugnas.landryzetam.net` leaks nothing and survives re-addressing. A literal IP
does both badly. Always check for a hostname first — most of this estate has one.

## 2. The cluster needs the value → SOPS

An allowlist CIDR or an NFS server with no DNS name has to be readable by the
cluster, so it cannot move out of the manifest. Encrypt it in place instead.

`encrypted_regex` is not limited to `data`/`stringData` — target the field:

```bash
sops -e --age <recipient> --encrypted-regex '^(sourceRange)$' mw.yaml > out.yaml
sops -d apps/staging/<app>/<file>.yaml    # view
sops    apps/staging/<app>/<file>.yaml    # edit in place
```

Encrypted resources live in the **staging overlay**, next to the SOPS secrets,
not in `apps/base/`.

## 3. It is explanation → private/

Why a range is allowed, what sits on which VLAN, which box is which — that is
documentation, not configuration. It goes in `private/<namespace>.md`. The whole
`private/` directory is gitignored. The manifest carries a pointer, never the
detail.

## Worked example

| file | holds | committed |
|---|---|---|
| `apps/staging/pv-browser/lan-only-middleware.yaml` | the allowlist CIDRs, encrypted | yes |
| `private/pv-browser.md` | the same ranges in plaintext, with rationale | no |
| `apps/base/pv-browser/storage.yaml` | NFS server as a hostname | yes |

## Checking yourself

```bash
git show HEAD | grep -E "^\+.*([0-9]{1,3}\.){3}[0-9]{1,3}"
```

Run it before pushing. It should return nothing.
