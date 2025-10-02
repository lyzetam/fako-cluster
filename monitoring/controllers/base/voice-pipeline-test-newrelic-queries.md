# Finding Your Voice Pipeline Metrics in New Relic

## Quick Access URLs

### 1. Direct Query Builder
Go to: https://one.newrelic.com/nrai > Query your data

### 2. Metrics Explorer
Go to: https://one.newrelic.com/metrics

## Step-by-Step: Finding Your Metrics

### Method 1: Query Builder (Recommended)

1. **Go to New Relic One** > **Query your data**

2. **Copy and paste these exact NRQL queries:**

#### See All Your Metrics (Last Hour)
```sql
SELECT * FROM Metric 
WHERE metricName LIKE 'voice_pipeline%' 
SINCE 1 hour ago 
LIMIT MAX
```

#### Latest Test Results in Seconds
```sql
SELECT latest(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds'
FACET stage 
SINCE 30 minutes ago
```

#### View as Time Series
```sql
SELECT average(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage IN ('openwakeword', 'whisper', 'ollama', 'piper', 'total')
FACET stage 
SINCE 1 hour ago 
TIMESERIES
```

#### Total Pipeline Latency Trend
```sql
SELECT average(voice_pipeline_latency_seconds) as 'Avg Latency (s)',
       max(voice_pipeline_latency_seconds) as 'Max Latency (s)',
       min(voice_pipeline_latency_seconds) as 'Min Latency (s)'
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage = 'total'
SINCE 1 hour ago 
TIMESERIES AUTO
```

### Method 2: Metrics Explorer

1. Go to **New Relic One** > **Explorer** > **Metrics**
2. In the search box, type: `voice_pipeline`
3. You should see:
   - `voice_pipeline_latency_seconds`
   - `voice_pipeline_latency_ms`
   - `voice_pipeline_audio_size_bytes`

4. Click on any metric to explore
5. Use the **Dimension** dropdown to select `stage`

### Method 3: Create a Dashboard

1. **Go to Dashboards** > **Create a dashboard**
2. **Add widgets with these queries:**

#### Widget 1: Current Latencies
```sql
SELECT latest(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds'
FACET stage
```
- Chart type: Bar chart
- Title: "Voice Pipeline Latency by Stage (seconds)"

#### Widget 2: Pipeline Trend
```sql
SELECT average(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage = 'total'
TIMESERIES
```
- Chart type: Line chart
- Title: "Total Pipeline Latency Over Time"

#### Widget 3: Component Performance
```sql
SELECT average(voice_pipeline_latency_seconds) as 'Avg',
       max(voice_pipeline_latency_seconds) as 'Max',
       percentile(voice_pipeline_latency_seconds, 95) as 'P95'
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds'
AND stage != 'total'
FACET stage
```
- Chart type: Table
- Title: "Component Performance Statistics"

## Troubleshooting: Metrics Not Showing Up?

### 1. Wait for Scraping (2-5 minutes)
New Relic Prometheus agent scrapes every 30s-1min. After deploying annotations, wait a few minutes.

### 2. Check if Service Has Annotations
```bash
kubectl get svc -n voice-pipeline-test voice-pipeline-test -o yaml | grep -A4 annotations
```

Should show:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
  newrelic.io/scrape: "true"
```

### 3. Verify Metrics Are Being Exposed
```bash
curl http://<node-ip>:30880/metrics | grep voice_pipeline
```

### 4. Check New Relic Agent Logs
```bash
kubectl logs -n nrdot-collector newrelic-bundle-newrelic-prometheus-agent-0 --tail=100 | grep voice
```

### 5. Force Metric Generation
Run the test a few times to ensure data points exist:
```bash
for i in {1..3}; do
  curl -X POST http://<node-ip>:30880/test \
    -H "Content-Type: application/json" \
    -d '{"timeout": 30}' > /dev/null 2>&1
  sleep 5
done
```

## Example: What You Should See

When you run the NRQL query, you should see data like:
```
stage            | voice_pipeline_latency_seconds
-----------------|--------------------------------
openwakeword     | 0.050
whisper          | 30.455  (timeout issue)
ollama           | 2.559
piper            | 2.004
total            | 35.077
```

## Direct Link Template
Replace `YOUR_ACCOUNT_ID` with your New Relic account ID:
```
https://one.newrelic.com/launcher/nr1-core.explorer?platform[accountId]=YOUR_ACCOUNT_ID&platform[$isFallbackTimeRange]=true&platform[timeRange][duration]=1800000&pane=eyJuZXJkbGV0SWQiOiJkYXRhLWV4cGxvcmF0aW9uLnF1ZXJ5LWJ1aWxkZXIiLCJpbml0aWFsQWN0aXZlSW50ZXJmYWNlIjoibnJxbEVkaXRvciIsImluaXRpYWxOcnFsVmFsdWUiOiJTRUxFQ1QgKiBGUk9NIE1ldHJpYyBXSEVSRSBtZXRyaWNOYW1lIExJS0UgJ3ZvaWNlX3BpcGVsaW5lJScgU0lOQ0UgMSBob3VyIGFnbyJ9
```

## Pro Tips

1. **Set up Alerts**: Alert when total latency > 15 seconds
2. **Create SLIs**: Track P95 latency as Service Level Indicator
3. **Add to Existing Dashboards**: Embed voice pipeline metrics in your main dashboards
4. **Use Workloads**: Group voice pipeline with related services

## Your Data is Available as JSON Too

The API response you're seeing:
```json
{
  "openwakeword_s": 0.050,
  "whisper_s": 30.455,
  "ollama_s": 2.559,
  "piper_s": 2.004,
  "total_s": 35.077,
  "piper_note": "Piper uses Wyoming protocol (TCP), not HTTP REST"
}
```

Is being converted to Prometheus metrics:
```
voice_pipeline_latency_seconds{stage="openwakeword"} 0.050
voice_pipeline_latency_seconds{stage="whisper"} 30.455
voice_pipeline_latency_seconds{stage="ollama"} 2.559
voice_pipeline_latency_seconds{stage="piper"} 2.004
voice_pipeline_latency_seconds{stage="total"} 35.077
```

These metrics are then scraped by New Relic and queryable via NRQL!
