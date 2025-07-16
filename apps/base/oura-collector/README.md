# Oura Collector

This application collects health data from the Oura API and stores it in PostgreSQL.

## Architecture

### Continuous Collection (Deployment)
- The main `deployment.yaml` runs continuously
- Uses "smart backfill" to detect the last data date and only collect new data
- Configured to backfill up to 30 days on startup if needed
- Collects data every hour (COLLECTION_INTERVAL: 3600)

### Scheduled Collection (CronJob)
- The `cronjob.yaml` runs every 6 hours as a backup
- Collects the last 3 days of data to handle any gaps
- Useful if the main deployment fails or is down for maintenance

### Manual Backfill (Job)
- The `backfill-job.yaml` is NOT included in the regular deployment
- Used for initial setup or recovering from extended outages
- Currently configured to collect 30 days of historical data
- To run manually: `kubectl apply -f apps/base/oura-collector/backfill-job.yaml`

## Why Data Might Appear Stale

1. **Backfill Job Running**: Previously, the backfill job was included in the kustomization, causing it to run with every Flux reconciliation. This has been fixed.

2. **Deployment Issues**: If the collector deployment crashes or fails, data collection stops. The smart backfill will catch up when it restarts.

3. **API Issues**: Check the collector logs for authentication or API errors.

## Troubleshooting

### Check collector status:
```bash
kubectl get pods -n dev-oura-collector
kubectl logs -n dev-oura-collector <pod-name> --tail=50
```

### Force a data refresh:
```bash
kubectl rollout restart deployment oura-collector -n dev-oura-collector
```

### Run manual backfill (if needed):
```bash
kubectl apply -f apps/base/oura-collector/backfill-job.yaml
```

## Configuration

- **DAYS_TO_BACKFILL**: 
  - Deployment: 30 days (for startup recovery)
  - CronJob: 3 days (for gap filling)
  - Backfill Job: 30 days (for manual recovery)
