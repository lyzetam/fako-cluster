#!/usr/bin/env bash
# make verify — render every Flux root offline so a broken manifest fails here,
# not in the cluster. No cluster access needed. `kustomize` is not installed on
# the Macs; `kubectl kustomize` is the same renderer.
#
#   VERIFY_SERVER=1 make verify   # also server-side dry-run against the current
#                                 # kube context (slow; Flux postBuild ${VARS}
#                                 # are NOT substituted, so expect some rejects)
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
    if kubectl apply --dry-run=server -f "$out" >/dev/null 2>"$tmp/err"; then
      echo "ok    server dry-run $r"
    else
      echo "FAIL  server dry-run $r"; sed 's/^/      /' "$tmp/err" | head -20; fail=1
    fi
  done
fi

exit "$fail"
