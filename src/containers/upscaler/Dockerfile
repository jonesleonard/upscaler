FROM nvidia/cuda:13.0.0-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip git ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir awscli

# ---- Upgrade pip to avoid dependency resolution bugs ----
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# ---- Install PyTorch with CUDA support ----
# Install PyTorch nightly with CUDA 13.0 support before SeedVR2 dependencies
RUN pip3 install --no-cache-dir --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu130
    
# ---- Install SeedVR2 CLI ----
# This is intentionally “repo-based” so you can pin a commit/tag.
ARG SEEDVR2_REPO="https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
ARG SEEDVR2_REF="main"

RUN git clone "$SEEDVR2_REPO" /opt/seedvr2 \
    && cd /opt/seedvr2 \
    && git checkout "$SEEDVR2_REF" \
    && pip3 install --no-cache-dir -r requirements.txt \
    && pip3 install --no-cache-dir .

WORKDIR /app
COPY upscale_one_segment.sh /app/upscale_one_segment.sh
RUN chmod +x /app/upscale_one_segment.sh

ENTRYPOINT ["/app/upscale_one_segment.sh"]