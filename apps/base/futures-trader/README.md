# futures-trader — IBKR gold-futures scalper (/MGC) — STAGED, NOT ACTIVE

These manifests are **deliberately NOT referenced by any parent kustomization** — Flux
ignores this directory. The service cannot run yet: it needs IBKR paper credentials
(Plan 2.5, operator step) and the IB fill-callback wiring (Plan 4 part 2 — until then
the daily-loss cap is dormant by design and the service warns loudly every tick).

Image: `lzetam/quantum-trades-futures-trader:latest` (built by
`.github/workflows/build-futures-trader.yml` in the quantum-trades repo, path-isolated
to `futures-trader/**`).

## Activation checklist (in order)
1. **Plan 2.5 (operator):** create an IBKR paper account; store creds in AWS Secrets
   Manager at `quantum-trades/futures/ibkr-paper` (keys: `TWS_USERID`, `TWS_PASSWORD`);
   validate locally per `futures-trader/docs/ibkr-paper-setup.md`
   (`uv run pytest -m integration` → 4 tests pass).
2. **Plan 4 part 2 (code):** wire the IB fill-callback → `save_trade()` so the
   daily-loss cap activates. Do NOT trade real sessions before this.
3. Set `AGENTS_API_KEY`-equivalent (`FUTURES_API_KEY`) in the AWS secret.
4. Wire this directory into the apps kustomization (one line), commit, push,
   `flux reconcile kustomization apps --with-source`.

## Architecture (spec 2026-05-27)
- `futures-trader` Deployment (this repo's image, port 8000, `/health` public)
- `ib-gateway` Deployment (`gnzsnz/ib-gateway`, separate pod by design — NOT a sidecar)
- NetworkPolicy: ONLY futures-trader may reach the IB Gateway API port (4002 paper)
- ExternalSecret pulls IBKR creds from AWS SM
- Paper-first: IB Gateway `TRADING_MODE=paper`, port 4002
