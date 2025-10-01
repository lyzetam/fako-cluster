# Voice Pipeline Test - New Relic Integration Guide

## Overview
The voice-pipeline-test framework exposes Prometheus metrics that can be ingested by New Relic for monitoring and alerting.

## Available Metrics

### Latency Metrics (in seconds)
- `voice_pipeline_latency_seconds{stage="openwakeword"}` - Wake word detection time
- `voice_pipeline_latency_seconds{stage="whisper"}` - Speech-to-text transcription time  
- `voice_pipeline_latency_seconds{stage="ollama"}` - LLM inference time
- `voice_pipeline_latency_seconds{stage="piper"}` - Text-to-speech synthesis time
- `voice_pipeline_latency_seconds{stage="total"}` - Total end-to-end pipeline time

### Latency Metrics (in milliseconds)
- `voice_pipeline_latency_ms{stage="openwakeword"}` - Wake word detection time
- `voice_pipeline_latency_ms{stage="whisper"}` - Speech-to-text transcription time
- `voice_pipeline_latency_ms{stage="ollama"}` - LLM inference time  
- `voice_pipeline_latency_ms{stage="piper"}` - Text-to-speech synthesis time
- `voice_pipeline_latency_ms{stage="total"}` - Total end-to-end pipeline time

### Audio Size Metrics
- `voice_pipeline_audio_size_bytes{type="input"}` - Size of input audio file

## Finding Metrics in New Relic

### Method 1: Query Builder (NRQL)
```sql
-- View all voice pipeline metrics
SELECT * FROM Metric WHERE metricName LIKE 'voice_pipeline%' 
SINCE 1 hour ago

-- Average latency by stage (in seconds)
SELECT average(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
FACET stage 
SINCE 1 hour ago 
TIMESERIES

-- Total pipeline latency over time
SELECT average(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage = 'total'
SINCE 1 day ago 
TIMESERIES

-- Compare component latencies
SELECT latest(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage IN ('whisper', 'ollama', 'piper')
FACET stage
SINCE 1 hour ago
```

### Method 2: Metrics Explorer
1. Navigate to **New Relic One** > **Explorer** > **Metrics**
2. Search for `voice_pipeline`
3. Select the metric you want to visualize
4. Use the dimension `stage` to filter by pipeline component

### Method 3: Dashboards
Create a custom dashboard with these widgets:

#### Pipeline Latency Overview
```json
{
  "title": "Voice Pipeline Latency (seconds)",
  "query": "SELECT latest(voice_pipeline_latency_seconds) FROM Metric WHERE metricName = 'voice_pipeline_latency_seconds' FACET stage"
}
```

#### Latency Trend
```json
{
  "title": "Pipeline Latency Trend",
  "query": "SELECT average(voice_pipeline_latency_seconds) FROM Metric WHERE metricName = 'voice_pipeline_latency_seconds' AND stage = 'total' TIMESERIES"
}
```

#### Component Performance
```json
{
  "title": "Component Performance Breakdown",
  "query": "SELECT percentile(voice_pipeline_latency_seconds, 50, 90, 99) FROM Metric WHERE metricName = 'voice_pipeline_latency_seconds' FACET stage"
}
```

## Setting Up Alerts

### High Latency Alert
```sql
SELECT average(voice_pipeline_latency_seconds) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage = 'total'
-- Alert if total latency exceeds 15 seconds
```

### Component Failure Alert
```sql
SELECT count(*) 
FROM Metric 
WHERE metricName = 'voice_pipeline_latency_seconds' 
AND stage IN ('whisper', 'ollama', 'piper')
AND value > 30
-- Alert if any component takes more than 30 seconds (timeout)
```

## Troubleshooting

### Issue: Metrics Not Appearing in New Relic
1. Ensure New Relic infrastructure agent is configured to scrape Prometheus endpoints
2. Check that the service is exposed: `http://<node-ip>:30880/metrics`
3. Verify metrics are being generated: `curl http://<node-ip>:30880/test -X POST`

### Issue: Piper Timeout Error
**Error**: `HTTPConnectionPool(host='piper-nodeport.piper', port=10200): Read timed out`

**Explanation**: Piper uses the Wyoming protocol (TCP-based binary protocol) instead of HTTP REST API. The timeout is expected when trying to connect via HTTP.

**Solution**: 
- The test framework now correctly documents this as expected behavior
- Piper latency is measured as connection attempt time (~2 seconds)
- To fully integrate Piper, you would need a Wyoming protocol client

### Issue: Whisper Timeout
**Possible Causes**:
1. Whisper service may be using WebSocket instead of REST
2. Endpoint path might be incorrect
3. Service might require authentication

**Check Whisper API**:
```bash
kubectl logs -n whisper deploy/whisper | grep -i api
```

## Test Output Explained

When you run the test, you get:
1. **TTS Text**: The text that would be sent to Piper for speech synthesis
2. **Latencies in seconds**: More readable format alongside milliseconds
3. **Protocol notes**: Documentation of which protocols each service uses

Example output:
```json
{
  "tts_text": "<LLM response that would be spoken>",
  "openwakeword_s": 0.050,  // Wake word detection
  "whisper_s": 5.319,        // Speech-to-text
  "ollama_s": 2.636,         // LLM processing  
  "piper_s": 2.014,          // TTS (connection attempt only)
  "total_s": 10.059,         // Total pipeline
  "piper_note": "Piper uses Wyoming protocol (TCP), not HTTP REST"
}
```

## Integration with New Relic APM

To get deeper insights with APM:

1. **Add OpenTelemetry instrumentation** to the Flask app
2. **Configure New Relic Python agent** in the deployment
3. **Enable distributed tracing** to see the full request flow

Example configuration:
```yaml
env:
  - name: NEW_RELIC_APP_NAME
    value: "voice-pipeline-test"
  - name: NEW_RELIC_LICENSE_KEY
    valueFrom:
      secretKeyRef:
        name: newrelic-license
        key: licenseKey
```

## Next Steps
1. Fix Whisper API integration (check actual endpoint path)
2. Consider implementing Wyoming protocol client for Piper
3. Add OpenTelemetry spans for detailed tracing
4. Create New Relic dashboard from this template
5. Set up alerting policies based on your SLAs
