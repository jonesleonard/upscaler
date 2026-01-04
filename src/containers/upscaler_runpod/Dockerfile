# syntax=docker/dockerfile:1.4
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS base

# Metadata
LABEL maintainer="maintainer@maintain.com"
LABEL description="SeedVR2 Video Upscaler with CUDA support"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# ==============================================================================
# Builder Stage: Install dependencies and build tools
# ==============================================================================
FROM base AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3=3.10.* \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    build-essential \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip, setuptools, wheel
RUN pip install --no-cache-dir --upgrade \
    pip==24.0.* \
    setuptools==69.* \
    wheel==0.43.*

# Install AWS CLI
RUN pip install --no-cache-dir awscli==1.32.*

# Install PyTorch with CUDA support
RUN pip install --no-cache-dir --pre \
    torch \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# Preinstall sageattention (used for ATTENTION_MODE=sageattn_2/3)
RUN pip install --no-cache-dir sageattention

# Install SeedVR2
ARG SEEDVR2_REPO="https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
ARG SEEDVR2_REF="v2.5.23"

RUN git clone --depth 1 --branch "$SEEDVR2_REF" "$SEEDVR2_REPO" /opt/seedvr2 \
    && cd /opt/seedvr2 \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir . \
    && rm -rf /opt/seedvr2/.git

# Verify SeedVR2 installation
RUN python /opt/seedvr2/inference_cli.py --help

# Copy and install application requirements
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# ==============================================================================
# Runtime Stage: Minimal runtime image
# ==============================================================================
FROM base AS runtime

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3=3.10.* \
    ffmpeg \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/seedvr2 /opt/seedvr2

# Set PATH for virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user and group
RUN groupadd -r appuser -g 1000 \
    && useradd -r -u 1000 -g appuser -m -s /sbin/nologin appuser

# Set working directory
WORKDIR /app

# Create work directories with proper ownership
RUN mkdir -p /work/in /work/out /models \
    && chown -R appuser:appuser /work /models /app

# Copy application files
COPY --chown=appuser:appuser handler.py /app/
COPY --chown=appuser:appuser upscale_segment.sh /app/
RUN chmod +x /app/upscale_segment.sh

# Switch to non-root user
USER appuser

# Health check - adjust based on your handler's health endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1

# Run application
CMD ["python", "-u", "handler.py"]
