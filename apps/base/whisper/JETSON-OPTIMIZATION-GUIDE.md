# Whisper Jetson Optimization Guide

## Overview
This guide documents the optimizations and configurations for running Whisper on NVIDIA Jetson Orin Nano (jetson02).

## Hardware Specifications - Jetson Orin Nano
- **CPU**: 6-core ARM Cortex-A78AE @ 1.5GHz
- **GPU**: 1024-core NVIDIA Ampere with 32 Tensor Cores
- **Memory**: 8GB 128-bit LPDDR5 (shared between CPU and GPU)
- **Compute Capability**: 8.7

## Current Configuration

### Container Image
Using the official `rhasspy/wyoming-whisper:latest` image which supports both x86_64 and ARM64 architectures. This eliminates the need for custom ARM64 image builds.

### Node Selection
The deployment is configured to run specifically on `jetson02`:
```yaml
nodeSelector:
  kubernetes.io/hostname: jetson02
```

### Model Configuration
Using the **small** model for optimal performance on Jetson:
- Model: `small` (reduced from `large` for memory constraints)
- Compute Type: `float16` (optimal for Jetson GPU)
- Language: `en`
- Beam Size: 1 (conservative for low memory)

### Memory Management
```yaml
resources:
  requests:
    memory: "2Gi"     # Conservative start
    cpu: "2000m"      # 2 cores
    nvidia.com/gpu: 1
  limits:
    memory: "4Gi"     # Half of available memory
    cpu: "4000m"      # 4 of 6 cores
    nvidia.com/gpu: 1
```

### GPU Optimizations
```yaml
env:
- name: PYTORCH_CUDA_ALLOC_CONF
  value: "max_split_size_mb:32,garbage_collection_threshold:0.9,expandable_segments:False"
- name: CUDA_LAUNCH_BLOCKING
  value: "1"  # Synchronous operations for better memory management
- name: TORCH_CUDA_EMPTY_CACHE_INTERVAL
  value: "1"  # Clear CUDA cache after every batch
- name: TORCH_CUDA_ARCH_LIST
  value: "8.7"  # Jetson Orin Nano compute capability
```

### ARM-Specific Settings
```yaml
- name: GOARCH
  value: "arm64"
- name: GOOS
  value: "linux"
- name: OMP_NUM_THREADS
  value: "1"  # Prevent threading issues on ARM
```

### Performance Tuning
- Batch Size: 1 (conservative for low memory)
- Number of Workers: 1 (prevent memory issues)
- Max Speech Duration: 20s (reduced from 30s)
- VAD Threshold: 0.5
- Min Speech Duration: 250ms
- Speech Padding: 400ms

## Key Differences from GPU Deployment

| Setting | GPU (RTX 3050) | Jetson Orin Nano |
|---------|---------------|------------------|
| Model Size | large | small |
| Memory Limit | 6Gi | 4Gi |
| CPU Limit | 8 cores | 4 cores |
| Max Speech Duration | 30s | 20s |
| GPU Device | GPU 1 | GPU 0 |
| Node | (any GPU node) | jetson02 |

## Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n whisper
kubectl describe pod -n whisper whisper-jetson-xxxxx
```

### View Logs
```bash
kubectl logs -n whisper -l app=whisper-jetson
```

### GPU Memory Usage
```bash
kubectl exec -n whisper -it $(kubectl get pod -n whisper -l app=whisper-jetson -o name) -- nvidia-smi
```

### Test Whisper Service
```bash
# Port forward the service
kubectl port-forward -n whisper svc/whisper-gpu 10300:10300

# Test with a sample audio file
curl -X POST http://localhost:10300/api/asr \
  -F "audio=@sample.wav" \
  -F "language=en"
```

## Performance Expectations

- **Model Loading**: 60-120 seconds on Jetson (ARM + limited memory)
- **Inference Speed**: Slower than GPU deployment but still real-time capable
- **Memory Usage**: Stays within 4GB limit with small model
- **Transcription Quality**: Good quality with small model, suitable for most use cases

## Future Optimizations

1. **Model Quantization**: Consider INT8 quantization for faster inference
2. **TensorRT Integration**: Use TensorRT for optimized inference on Jetson
3. **Dynamic Batching**: Implement dynamic batching when memory allows
4. **Model Caching**: Implement better model caching strategies
5. **Multi-Instance**: Consider running multiple smaller models for different languages

## Notes

- The Jetson deployment prioritizes stability over speed
- Small model provides good balance between quality and resource usage
- Host IPC is enabled for better shared memory access
- Conservative probe delays account for slower ARM initialization
