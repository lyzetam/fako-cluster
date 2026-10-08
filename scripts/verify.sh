#!/usr/bin/env bash
# make verify — render every Flux root offline so a broken manifest fails here,
# not in the cluster. No cluster access needed. `kustomize` is not installed on
# the Macs; `kubectl kustomize` is the same renderer.
#
#   VERIFY_SERVER=1 make verify   # also server-side dry-run against the current
#                                 # kube context (~2 min). SOPS-encrypted Secrets
#                                 # are skipped: kubectl's strict validation
#                                 # rejects their top-level `sops:` block, which
#                                 # Flux strips after decrypting.
set -euo pipefail
cd "$(dirname "$0")/.."

# One entry per Flux Kustomization `path:` in clusters/staging/*.yaml.
ROOTS=(
  apps/staging
  infrastructure/controllers/staging
  infrastructure/configs/staging
  monitoring/controllers/staging
  monitoring/configs/staging
)

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
for r in "${ROOTS[@]}"; do
  out="$tmp/$(echo "$r" | tr / _).yaml"
  if kubectl kustomize "$r" >"$out" 2>"$tmp/err"; then
    printf 'ok    %-36s %4d objects\n' "$r" "$(grep -c '^kind:' "$out")"
  else
    printf 'FAIL  %s\n' "$r"; sed 's/^/      /' "$tmp/err"; fail=1
  fi
done

if [[ "${VERIFY_SERVER:-0}" == "1" ]]; then
  for r in "${ROOTS[@]}"; do
    out="$tmp/$(echo "$r" | tr / _).yaml"
    [[ -s "$out" ]] || continue
    # Drop SOPS documents (top-level `sops:` key); everything else goes to the API.
    awk 'BEGIN{RS="\n---\n"; ORS="\n---\n"} !/(^|\n)sops:\n/' "$out" >"$tmp/plain.yaml"
    if kubectl --request-timeout=120s apply --dry-run=server -f "$tmp/plain.yaml" >/dev/null 2>"$tmp/err"; then
      printf 'ok    server dry-run %-20s %4d objects (%d SOPS secrets skipped)\n' "$r" \
        "$(grep -c '^kind:' "$tmp/plain.yaml")" "$(( $(grep -c '^kind:' "$out") - $(grep -c '^kind:' "$tmp/plain.yaml") ))"
    else
      echo "FAIL  server dry-run $r"; fail=1
      # First 20 real errors; the apply also warns about every object's missing
      # last-applied annotation (owned by kustomize-controller), which is noise.
      grep -m20 -v '^Warning:' "$tmp/err" | sed 's/^/      /' || true
    fi
  done
fi

exit "$fail"
