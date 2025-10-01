# New Relic eBPF Dashboard

This directory contains a pre-configured New Relic dashboard for visualizing eBPF metrics collected by Pixie.

## Dashboard: newrelic-ebpf-dashboard.json

A comprehensive dashboard with 5 pages covering:
- **HTTP & API Performance** - Request rates, latencies, errors, and endpoint analysis
- **Network Performance** - Throughput, TCP connections, retransmissions, and bandwidth
- **DNS & Service Discovery** - DNS queries, response times, and domain analysis
- **Service Dependencies** - Service maps, inter-service communication, and database connections
- **Pod & Container Metrics** - CPU, memory, restarts, and resource utilization

## Import Instructions

### Method 1: Import via New Relic UI (Recommended)

1. **Log in to New Relic One**
   ```
   https://one.newrelic.com
   ```

2. **Navigate to Dashboards**
   - Click on **Dashboards** in the left sidebar
   - Click **Import dashboard** button (top right)

3. **Upload JSON**
   - Click **Upload a dashboard JSON**
   - Select `newrelic-ebpf-dashboard.json` from this directory
   - Click **Import dashboard**

4. **Configure Account**
   - The dashboard will prompt you to select your account
   - Choose the account where your "Fako-cluster" data is reporting
   - Click **Import**

5. **Verify**
   - The dashboard should now appear in your dashboards list
   - Data may take a few minutes to populate if Pixie was recently enabled

### Method 2: Import via New Relic CLI

1. **Install New Relic CLI** (if not already installed)
   ```bash
   brew install newrelic-cli
   ```

2. **Configure API Key**
   ```bash
   newrelic profile add --profile default --apiKey YOUR_USER_API_KEY --region us
   ```

3. **Import Dashboard**
   ```bash
   newrelic entity dashboard import --file monitoring/dashboards/newrelic-ebpf-dashboard.json
   ```

### Method 3: Import via API

```bash
# Replace YOUR_API_KEY and YOUR_ACCOUNT_ID
curl -X POST 'https://api.newrelic.com/graphql' \
  -H 'Content-Type: application/json' \
  -H 'API-Key: YOUR_API_KEY' \
  -d @- <<EOF
{
  "query": "mutation (\$dashboard: DashboardInput!) { dashboardCreate(accountId: YOUR_ACCOUNT_ID, dashboard: \$dashboard) { entityResult { guid name } errors { description } } }",
  "variables": {
    "dashboard": $(cat monitoring/dashboards/newrelic-ebpf-dashboard.json)
  }
}
EOF
```

## Viewing eBPF Data

### Prerequisites

Ensure the following are running in your cluster:
- ✅ Pixie (`newrelic-pixie` namespace)
- ✅ New Relic Infrastructure agent (`nrdot-collector` namespace)
- ✅ newrelic-eapm-agent (enabled in nrdot-collector)

### Verify Data Flow

1. **Check Pixie Pods**
   ```bash
   kubectl get pods -n newrelic-pixie
   ```

2. **Check eBPF Agent**
   ```bash
   kubectl get pods -n nrdot-collector -l app.kubernetes.io/name=newrelic-eapm-agent
   ```

3. **Query eBPF Data in New Relic**
   ```sql
   -- HTTP requests from eBPF
   FROM Span 
   SELECT count(*) 
   WHERE instrumentation.provider = 'pixie' 
   SINCE 1 hour ago

   -- Network metrics from eBPF
   FROM Metric 
   SELECT * 
   WHERE instrumentation.provider = 'pixie' 
   LIMIT MAX

   -- DNS queries from eBPF
   FROM Span 
   SELECT count(*) 
   WHERE instrumentation.provider = 'pixie' 
   AND name LIKE 'dns%'
   SINCE 1 hour ago
   ```

## Dashboard Pages Explained

### 1. HTTP & API Performance

**Key Metrics:**
- Request rate per second across all services
- P95 latency tracking
- Error rates and status code distribution
- Slowest endpoints identification

**Use Cases:**
- Identify performance bottlenecks
- Track API error rates
- Monitor endpoint latency trends

### 2. Network Performance

**Key Metrics:**
- Bytes sent/received per second
- Active TCP connections
- TCP retransmissions
- Network packet loss

**Use Cases:**
- Diagnose network issues
- Identify bandwidth-heavy pods
- Monitor connection stability

### 3. DNS & Service Discovery

**Key Metrics:**
- DNS query rate and latency
- Most queried domains
- DNS failures and response codes

**Use Cases:**
- Troubleshoot DNS resolution issues
- Identify chatty services
- Monitor service discovery health

### 4. Service Dependencies

**Key Metrics:**
- Service-to-service communication map
- Inter-service latency
- Database query performance
- Service call volumes

**Use Cases:**
- Understand service architecture
- Identify dependency bottlenecks
- Track database performance

### 5. Pod & Container Metrics

**Key Metrics:**
- CPU and memory usage by pod
- Container restart counts
- CPU throttling
- Pod phase distribution

**Use Cases:**
- Resource optimization
- Identify problematic pods
- Capacity planning

## Troubleshooting

### No Data Appearing

1. **Check Pixie Status**
   ```bash
   kubectl get pods -n newrelic-pixie -l app=pl-monitoring
   kubectl logs -n newrelic-pixie -l app=pl-monitoring --tail=50
   ```

2. **Verify License Key**
   ```bash
   kubectl get secret newrelic-license-key -n newrelic-pixie -o jsonpath='{.data.license-key}' | base64 -d
   ```

3. **Check Data in New Relic**
   - Go to New Relic One → Kubernetes → Fako-cluster
   - Navigate to "Pixie" tab
   - Verify Pixie is connected and showing data

4. **Query Raw Data**
   ```sql
   FROM Span SELECT * WHERE instrumentation.provider = 'pixie' LIMIT 100
   ```

### Dashboard Shows "No Data"

- Wait 5-10 minutes for data to start flowing
- Verify `accountId: 0` in the JSON is automatically replaced during import
- Check that your cluster name matches "Fako-cluster" in queries

### Queries Timing Out

If you have a very large cluster, you may need to:
1. Adjust time ranges (use shorter windows)
2. Add more filters to queries
3. Increase query limits in New Relic account settings

## Customizing the Dashboard

### Modify Queries

1. Click on any widget
2. Select **Edit** (pencil icon)
3. Modify the NRQL query
4. Click **Save**

### Add New Widgets

1. Click **+ Add widget**
2. Choose visualization type
3. Write NRQL query using these data sources:
   - `FROM Span WHERE instrumentation.provider = 'pixie'`
   - `FROM Metric WHERE instrumentation.provider = 'pixie'`
4. Save the widget

### Clone Dashboard

To create a custom version:
1. Open the dashboard
2. Click **...** (more options)
3. Select **Save as**
4. Give it a new name
5. Modify as needed

## Additional Resources

### New Relic Documentation
- [Pixie Integration](https://docs.newrelic.com/docs/kubernetes-pixie/auto-telemetry-pixie/)
- [NRQL Query Guide](https://docs.newrelic.com/docs/query-your-data/nrql-new-relic-query-language/)
- [Dashboard API](https://docs.newrelic.com/docs/apis/nerdgraph/examples/nerdgraph-dashboards/)

### Pixie Documentation
- [Pixie Overview](https://docs.px.dev/)
- [PxL Scripts](https://docs.px.dev/tutorials/pxl-scripts/)
- [Data Sources](https://docs.px.dev/about-pixie/data-sources/)

### GitOps Deployment

After making changes to `monitoring/controllers/base/nrdot-collector/release.yaml`:

```bash
# Commit changes
git add monitoring/
git commit -m "Enable newrelic-eapm-agent for APM auto-instrumentation"
git push

# Flux will automatically reconcile
# Check reconciliation status
kubectl get helmrelease -n nrdot-collector
kubectl describe helmrelease newrelic-bundle -n nrdot-collector
```

## Dashboard Maintenance

### Regular Updates

Check for new Pixie data types quarterly:
- New protocols (gRPC, AMQP, etc.)
- New language support
- Enhanced metrics

### Performance Optimization

If dashboard loads slowly:
1. Reduce time windows (use "Last 1 hour" instead of "Last 24 hours")
2. Add namespace filters to queries
3. Limit FACET results (currently set to 10-20)

## Support

For issues or questions:
1. Check [New Relic Support](https://support.newrelic.com)
2. Review [Pixie Troubleshooting Guide](https://docs.px.dev/installing-pixie/install-guides/troubleshooting/)
3. Verify configuration in `monitoring/controllers/base/newrelic-pixie/release.yaml`
