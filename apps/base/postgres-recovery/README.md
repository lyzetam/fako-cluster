# PostgreSQL Recovery Namespace

This directory contains manifests for a PostgreSQL recovery instance running on the `aitower` node with local hostPath storage.

## Purpose

- **Data Recovery Testing**: Restore backups to verify data integrity
- **Isolated Environment**: Separate from production postgres namespace
- **Local Storage**: Data stored at `/mnt/postgres-recovery/data` on aitower node (accessible via SSH)
- **Same Credentials**: Uses production credentials for easy pgadmin connectivity

## Architecture

```
postgres-recovery namespace
├── PostgreSQL 16 (single instance)
├── hostPath storage: /mnt/postgres-recovery/data
├── Restore Job: Restores keycloak, n8n, oura from latest backup
├── Service: postgres-recovery-service (port 5432)
└── Verification queries (ConfigMap)
```

## Deployment

### 1. Prerequisites
Ensure the aitower node has the directory created:
```bash
# SSH to aitower node
ssh aitower
sudo mkdir -p /mnt/postgres-recovery/data
sudo chown -R 999:999 /mnt/postgres-recovery/data  # postgres user in container
```

### 2. Deploy via Flux
```bash
# Flux will automatically deploy from apps/staging/postgres-recovery
# Or manually apply:
kubectl apply -k apps/staging/postgres-recovery/
```

### 3. Verify PostgreSQL is Running
```bash
kubectl get pods -n postgres-recovery
kubectl logs -n postgres-recovery postgres-recovery-0
```

### 4. Run Restore Job
```bash
# The restore job should run automatically
# Check its status:
kubectl get jobs -n postgres-recovery
kubectl logs -n postgres-recovery job/postgres-restore -f
```

## Connecting with pgadmin

Add a new server in pgadmin:

**Connection Details:**
- **Host**: `postgres-recovery-service.postgres-recovery.svc.cluster.local`
- **Port**: `5432`
- **Username**: `postgres`
- **Password**: (same as production - from AWS Secrets Manager)
- **Databases**: `keycloak`, `n8n`, `oura`

## Data Verification

The verification ConfigMap contains SQL queries to check data integrity.

### Quick Verification
```bash
# Get database summary
kubectl exec -n postgres-recovery postgres-recovery-0 -- psql -U postgres -c "
SELECT 
    datname as database,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
WHERE datname IN ('keycloak', 'n8n', 'oura')
ORDER BY datname;
"
```

### Detailed Queries
The ConfigMap contains detailed verification queries for each database:
- `keycloak-verification.sql` - Check Keycloak tables
- `n8n-verification.sql` - Check N8N workflows and executions
- `oura-verification.sql` - Check Oura health data
- `all-databases-summary.sql` - Overall summary

## Accessing Data Files via SSH

```bash
# SSH to aitower
ssh aitower

# View database files
ls -lah /mnt/postgres-recovery/data/pgdata/

# Check disk usage
du -sh /mnt/postgres-recovery/data/
```

## Cleanup

To remove the recovery namespace:
```bash
# Delete the kustomization from apps/staging/kustomization.yaml
# Or manually:
kubectl delete namespace postgres-recovery

# Cleanup local storage on aitower
ssh aitower
sudo rm -rf /mnt/postgres-recovery/
```

## Security Notes

- ✅ Uses same AWS Secrets Manager credentials as production
- ✅ Encrypted secrets with SOPS
- ✅ Isolated namespace (no impact on production)
- ✅ hostPath storage (not accessible from other nodes)
- ✅ Node selector ensures deployment only on aitower

## Troubleshooting

### Pod won't start
```bash
# Check node selector
kubectl get pods -n postgres-recovery -o wide

# Check if directory exists on aitower
ssh aitower "ls -ld /mnt/postgres-recovery/data"

# Check permissions
ssh aitower "ls -ld /mnt/postgres-recovery/data"
# Should be owned by 999:999
```

### Restore job fails
```bash
# Check backup PVC access
kubectl get pvc -n postgres

# View restore job logs
kubectl logs -n postgres-recovery job/postgres-restore

# Manually run restore
kubectl exec -n postgres-recovery postgres-recovery-0 -- bash -c "
psql -c 'CREATE DATABASE test;'
pg_restore -d test /backups/20251022_060000/keycloak.dump
"
```

### Cannot connect from pgadmin
```bash
# Check service
kubectl get svc -n postgres-recovery

# Test connection from another pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- \
  psql -h postgres-recovery-service.postgres-recovery.svc.cluster.local -U postgres -c '\l'
