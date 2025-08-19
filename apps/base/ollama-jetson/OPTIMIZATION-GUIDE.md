# Ollama Jetson Optimization Guide

## Performance Analysis Summary

Based on the logs and metrics from your Jetson Orin Nano deployment:

### Current Issues:
- **Response Time**: 51.4 seconds for first inference (way too slow)
- **Memory Usage**: 4.3GB/7.6GB (57% utilized) - leaving little headroom
- **Model Loading**: Takes ~15 seconds to load
- **KV Cache**: 640MB allocated for context
- **GPU Buffer**: 1472MB for model weights

### System Metrics During Inference:
- **GPU Utilization**: 87-98% during loading, drops to 0% when idle
- **Power Draw**: 18W during inference, 4-5W idle
- **CPU Usage**: Spikes to 45% during inference
- **Temperature**: GPU reaches 56°C under load

## Recommended Optimizations for Dedicated Node

### 1. **Memory & GPU Settings (With System Reserves)**
```yaml
# Keep all layers on GPU for maximum performance
OLLAMA_GPU_LAYERS: "999"  # All layers on GPU

# GPU memory with system headroom
OLLAMA_GPU_MEMORY: "4.5G"  # Reserve 0.5G for system

# Keep model loaded permanently
OLLAMA_KEEP_ALIVE: "24h"  # Always in memory
```
**Rationale**: While this is a dedicated node, we reserve 0.5GB GPU memory and 1GB system RAM to ensure Kubernetes, SSH, and system services remain responsive.

### 2. **Context & Batch Optimizations**
```yaml
# Reduce context for faster inference
OLLAMA_CONTEXT_LENGTH: "4096"  # Down from 8192

# Reduce batch size for lower latency
OLLAMA_BATCH_SIZE: "128"  # Down from 256
```
**Rationale**: 8192 context is overkill for a 2B model and contributes to the 51s response time. 4096 is sufficient for most conversations.

### 3. **CPU Thread Settings (With System Reserve)**
```yaml
# Reserve 1 core for system stability
OLLAMA_NUM_THREAD: "5"  # Use 5 of 6 cores
GOMAXPROCS: "5"  # Match thread count
```
**Rationale**: Reserving 1 CPU core ensures system services (kubelet, SSH, logging) remain responsive, preventing node "NotReady" states and maintaining debuggability.

## Expected Improvements

With these optimizations on a dedicated node:
- **Response time**: Reduced from 51s to ~5-10s (context reduction is key)
- **Instant availability**: Model always loaded, no cold starts
- **Maximum GPU utilization**: All layers on GPU for fastest inference
- **Consistent performance**: No resource competition from other workloads

## Configuration Profiles for Dedicated Node

### Current Optimized (Balanced with System Reserves):
```yaml
OLLAMA_CONTEXT_LENGTH: "4096"
OLLAMA_GPU_LAYERS: "999"
OLLAMA_BATCH_SIZE: "128"
OLLAMA_KEEP_ALIVE: "24h"
OLLAMA_GPU_MEMORY: "4.5G"
OLLAMA_NUM_THREAD: "5"
```

### Maximum Speed (minimal context):
```yaml
OLLAMA_CONTEXT_LENGTH: "2048"
OLLAMA_GPU_LAYERS: "999"
OLLAMA_BATCH_SIZE: "64"
OLLAMA_KEEP_ALIVE: "24h"
OLLAMA_GPU_MEMORY: "4.5G"
OLLAMA_NUM_THREAD: "5"
```

### Maximum Context (slower but more memory):
```yaml
OLLAMA_CONTEXT_LENGTH: "8192"
OLLAMA_GPU_LAYERS: "999"
OLLAMA_BATCH_SIZE: "256"
OLLAMA_KEEP_ALIVE: "24h"
OLLAMA_GPU_MEMORY: "4.5G"
OLLAMA_NUM_THREAD: "5"
```

## How to Apply Optimizations

1. **Option A**: Use the optimized configmap directly:
   ```bash
   kubectl apply -f apps/base/ollama-jetson/configmap-optimized.yaml
   kubectl rollout restart deployment/ollama-jetson -n ollama-jetson
   ```

2. **Option B**: Update the existing configmap:
   ```bash
   cp apps/base/ollama-jetson/configmap-optimized.yaml apps/base/ollama-jetson/configmap.yaml
   git add apps/base/ollama-jetson/configmap.yaml
   git commit -m "Optimize Ollama config for better performance"
   git push
   # Let Flux sync the changes
   ```

## Monitoring Performance

After applying optimizations, monitor:
```bash
# Watch logs
kubectl logs -f deployment/ollama-jetson -n ollama-jetson

# Monitor resource usage
tegrastats

# Test inference time
time curl -X POST http://jetson01:11434/api/generate \
  -d '{"model":"granite3.3:2b","prompt":"Hello, how are you?"}'
```

## Model-Specific Notes

### granite3.3:2b
- Works well with voice pipelines
- Clean responses without tool/function exposure
- Optimal with 4096 context
- Can run with all layers on GPU

### cogito:3b  
- May expose internal function calls in responses
- Not recommended for voice pipelines
- Slightly larger memory footprint
- Keep as backup model only

## Future Considerations

1. **Consider smaller models** for even faster responses:
   - `gemma2:2b` - Google's efficient 2B model
   - `phi3:mini` - Microsoft's 3.8B model optimized for edge

2. **Implement request caching** to avoid regenerating common responses

3. **Use streaming responses** to reduce perceived latency

4. **Consider quantization** to INT4 for even lower memory usage
