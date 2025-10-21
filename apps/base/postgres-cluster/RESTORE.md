# PostgreSQL Backup and Restoration Guide

## Backup Overview

The automated backup system creates daily backups at 2:00 AM of:
- All databases (oura, keycloak, n8n, app)
- Database roles and permissions
- Stored in NFS-backed PVC: `postgres-backup` (100Gi)
- Retention: 30 days

## What Gets Backed Up

✅ **Complete Database Contents:**
- All tables, indexes, sequences, views, functions
- All data from every database
- Stored procedures, triggers, constraints

✅ **Database Roles:**
- All users (postgres, app, admin)
- Passwords and permissions

❌ **NOT Backed Up:**
- PostgreSQL cluster configuration (managed by Git)
- Kubernetes resources (managed by GitOps)

## Full Restoration Process

### Step 1: Deploy PostgreSQL Cluster
```bash
# This creates the cluster from postgres-cluster.yaml in Git
flux reconcile kustomization apps --with-source
```

### Step 2: Wait for Cluster Ready
```bash
kubectl wait --for=condition=Ready cluster/postgres-cluster -n postgres --timeout=5m
```

### Step 3: List Available Backups
```bash
kubectl exec -n postgres postgres-cluster-1 -- ls -lh /backups
# Note the TIMESTAMP directory you want to restore
```

### Step 4: Restore Database Roles
```bash
TIMESTAMP="20241021_020000"  # Replace with actual timestamp

kubectl exec -n postgres postgres-cluster-1 -- \
  psql -U postgres -f /backups/${TIMESTAMP}/roles.sql
```

### Step 5: Restore Each Database

**Restore oura database:**
```bash
kubectl exec -n postgres postgres-cluster-1 -- \
  pg_restore -U postgres -d oura -c --if-exists \
  /backups/${TIMESTAMP}/oura.dump
```

**Restore keycloak database:**
```bash
kubectl exec -n postgres postgres-cluster-1 -- \
  pg_restore -U postgres -d keycloak -c --if-exists \
  /backups/${TIMESTAMP}/keycloak.dump
```

**Restore n8n database:**
```bash
kubectl exec -n postgres postgres-cluster-1 -- \
  pg_restore -U postgres -d n8n -c --if-exists \
  /backups/${TIMESTAMP}/n8n.dump
```

**Restore app database:**
```bash
kubectl exec -n postgres postgres-cluster-1 -- \
  pg_restore -U postgres -d app -c --if-exists \
  /backups/${TIMESTAMP}/app.dump
```

### Step 6: Verify Restoration
```bash
# Check databases exist
kubectl exec -n postgres postgres-cluster-1 -- \
  psql -U postgres -c "\l"

# Check table counts in oura database
kubectl exec -n postgres postgres-cluster-1 -- \
  psql -U postgres -d oura -c "\dt"

# Verify data in keycloak
kubectl exec -n postgres postgres-cluster-1 -- \
  psql -U postgres -d keycloak -c "SELECT count(*) FROM users;"
```

### Step 7: Restart Dependent Services
```bash
# Restart services to reconnect to restored databases
kubectl rollout restart deployment/keycloak -n keycloak
kubectl rollout restart deployment/n8n -n n8n
kubectl rollout restart deployment/oura-collector -n oura-collector
```

## Manual Backup

To trigger a manual backup before maintenance:
```bash
kubectl create job postgres-backup-manual-$(date +%s) \
  --from=cronjob/postgres-backup -n postgres

# Monitor backup
kubectl logs -n postgres job/postgres-backup-manual-XXXXX -f
```

## Backup Files Structure

Each backup creates a timestamped directory:
```
/backups/
├── 20241021_020000/
│   ├── oura.dump          # Custom format pg_dump
│   ├── keycloak.dump
│   ├── n8n.dump
│   ├── app.dump
│   ├── roles.sql          # All database roles
│   └── manifest.txt       # Backup metadata
└── 20241022_020000/
    └── ...
```

## Recovery Time Objective (RTO)

- **Cluster deployment:** 5-10 minutes
- **Role restoration:** 30 seconds
- **Database restoration:** 2-5 minutes per database
- **Total estimated time:** 15-30 minutes for full recovery

## Important Notes

1. The backup system uses `pg_dump -Fc` (custom format) for databases
2. Backups include `--if-exists -c` flags for safe restoration
3. All backups are stored on NAS via NFS (persistent across cluster failures)
4. 30-day retention ensures monthly recovery point options
5. The PostgreSQL cluster configuration comes from Git (postgres-cluster.yaml)

## Disaster Recovery Checklist

- [ ] Verify backup exists and is recent
- [ ] Deploy PostgreSQL cluster via GitOps
- [ ] Wait for cluster to be ready
- [ ] Restore roles
- [ ] Restore all databases
- [ ] Verify data integrity
- [ ] Restart dependent services
- [ ] Test application functionality

## Testing Backups

It's recommended to test restoration periodically:
1. Create a test namespace
2. Deploy a test PostgreSQL instance
3. Restore a backup to the test instance
4. Verify data integrity
5. Clean up test resources
