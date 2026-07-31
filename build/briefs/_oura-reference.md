# Oura Collector Reference (Architecture Summary)

## Key files:
- Deployment: `/dev/fako-cluster/apps/base/oura-collector/deployment.yaml`
- Config: `/dev/fako-collector-config` (1h cadence, 30-day backfill, stale-data threshold 3 days)
- Secrets: ExternalSecret pulls postgres/app-user + oura/api-credentials from AWS Secrets Manager
- Image: `lzetam/oura-collector:latest`

## Data model (Postgres):
Tables: daily_summaries, sleep_periods, sessions, readiness, stress, activity, etc.
Schema: JSON columns for metric data (readiness_data, daily_sleep_data, activity_data)

## Collection flow:
1. Hourly CronJob trigger
2. Fetch last 30 days from Oura API
3. Upsert to Postgres (idempotent)
4. Log to stdout / Alert on stale data (3+ days no new data)

## Auth:
- Oura API token from AWS Secrets Manager (oura/api-credentials)
- Postgres user/pass from AWS Secrets Manager (postgres/app-user)
- ExternalSecrets Operator manages rotation (1h refresh interval)
