FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    ffmpeg \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip, setuptools, and wheel
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install AWS CLI for S3 operations
RUN pip3 install --no-cache-dir awscli

# Install PyTorch with CUDA 12.1 support
RUN pip3 install --no-cache-dir --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# Preinstall attention optimization libraries
RUN pip3 install --no-cache-dir sageattention

# Install SeedVR2 CLI from specific version
ARG SEEDVR2_REPO="https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
ARG SEEDVR2_REF="v2.5.23"

RUN git clone "$SEEDVR2_REPO" /opt/seedvr2 \
    && cd /opt/seedvr2 \
    && git checkout "$SEEDVR2_REF" \
    && pip3 install --no-cache-dir -r requirements.txt \
    && pip3 install --no-cache-dir .

# Create working directories
RUN mkdir -p /work/in /work/out /models

WORKDIR /app
COPY upscale.sh /app/upscale.sh
RUN chmod +x /app/upscale.sh

# Health check to verify CUDA is available
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import torch; assert torch.cuda.is_available()" || exit 1

ENTRYPOINT ["/app/upscale.sh"]