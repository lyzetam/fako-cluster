# WhisperX with GPU support for speaker diarization
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

# Install Python and system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install WhisperX and dependencies
RUN pip3 install --no-cache-dir \
    whisperx \
    torch \
    torchaudio

# Create directory for scripts
WORKDIR /app

# Set environment variables for PyTorch
ENV TORCH_HOME=/root/.cache/torch
ENV HF_HOME=/root/.cache/huggingface

CMD ["python3"]
