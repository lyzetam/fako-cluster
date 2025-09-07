# Voice Pipeline Monitoring

## Overview

This monitoring solution provides comprehensive network-level request timing and health monitoring for the voice pipeline services (Whisper → Ollama → Piper) using a hybrid approach with Blackbox Exporter and enhanced Alloy network flow monitoring.

## Components

### 1. Blackbox Exporter
- **Purpose**: External health checks and response time measurements
- **Location**: `monitoring/controllers/base/blackbox-exporter/`
- **Features**:
  - TCP connectivity checks for Wyoming protocol services
  - HTTP health checks for Ollama REST API
  - Service availability monitoring

### 2. Enhanced Alloy Configuration
- **Purpose**: Internal network flow monitoring and log collection
- **Location**: `monitoring/controllers/base/alloy/alloy-config.yaml`
- **Features**:
  - Network connection tracking between voice services
  - Real-time request flow metrics
  - Pod-to-pod communication latency

### 3. Probe CRDs
- **Location**: `monitoring/configs/base/voice-monitoring/`
- **Probes**:
  - `whisper-probe.yaml`: Monitors Whisper speech-to-text service (port 10300)
  - `ollama-probe.yaml`: Monitors Ollama LLM service (port 11434)
  - `piper-probe.yaml`: Monitors Piper text-to-speech service (port 10200)
  - `openwakeword-probe.yaml`: Monitors OpenWakeWord service (port 10400)

## Available Metrics

### Blackbox Exporter Metrics
```
# Service availability
probe_success{job="whisper-tcp"} # 1 = up, 0 = down
probe_success{job="ollama-http"}
probe_success{job="piper-tcp"}
probe_success{job="openwakeword-tcp"}

# Response time in seconds
probe_duration_seconds{job="whisper-tcp"}
probe_duration_seconds{job="ollama-http"}
probe_duration_seconds{job="piper-tcp"}
probe_duration_seconds{job="openwakeword-tcp"}

# TCP connection time
probe_tcp_duration_seconds{phase="connect"}
```

### Alloy Network Flow Metrics
```
# Inter-service connection tracking
network_connection_duration{src_service="whisper",dst_service="ollama"}
request_flow_latency{pipeline="voice_processing"}
tcp_connection_time{from="ollama",to="piper"}
```

## Grafana Dashboard Queries

### Voice Pipeline Health Overview
```promql
# Service Uptime
avg_over_time(probe_success{job=~"whisper-tcp|ollama-http|piper-tcp|openwakeword-tcp"}[5m])

# Average Response Times
avg(probe_duration_seconds{job=~"whisper-tcp|ollama-http|piper-tcp|openwakeword-tcp"})

# End-to-End Pipeline Latency
sum(probe_duration_seconds{job=~"whisper-tcp|ollama-http|piper-tcp"})
```

### Service-Specific Monitoring
```promql
# Whisper Response Time (P95)
histogram_quantile(0.95, sum(rate(probe_duration_seconds{job="whisper-tcp"}[5m])) by (le))

# Ollama Processing Time
probe_duration_seconds{job="ollama-http"}

# Piper TTS Latency
probe_duration_seconds{job="piper-tcp"}
```

### Alert Examples
```promql
# Voice Service Down Alert
probe_success{job=~"whisper-tcp|ollama-http|piper-tcp"} == 0

# High Latency Alert (>5s)
probe_duration_seconds{job=~"whisper-tcp|ollama-http|piper-tcp"} > 5

# Pipeline Degradation (>10s total)
sum(probe_duration_seconds{job=~"whisper-tcp|ollama-http|piper-tcp"}) > 10
```

## Deployment

The monitoring stack is deployed via Flux GitOps:

1. **Base configurations**: `monitoring/controllers/base/` and `monitoring/configs/base/`
2. **Staging overlays**: `monitoring/controllers/staging/` and `monitoring/configs/staging/`
3. **Kustomization**: Automatically included in the monitoring stack

## Testing

To verify the monitoring is working:

```bash
# Check blackbox-exporter is running
kubectl get pods -n monitoring | grep blackbox

# View probe targets
kubectl get probes -n monitoring

# Check metrics endpoint
kubectl port-forward -n monitoring svc/blackbox-exporter 9115:9115
# Visit http://localhost:9115/metrics

# Query Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Search for probe_* metrics
```

## Benefits

1. **No code changes required**: Works with existing public container images
2. **Real-time visibility**: See request timing at each pipeline stage
3. **Health monitoring**: Know immediately when services are down
4. **Performance tracking**: Identify bottlenecks in the voice pipeline
5. **GitOps ready**: Fully declarative and version controlled
