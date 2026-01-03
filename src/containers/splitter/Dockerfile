FROM python:3.11-slim

# Build arguments for image labels
ARG BUILD_DATE="unknown"
ARG VERSION="unknown"
ARG GIT_SHA="unknown"

# OCI Image Labels
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
  org.opencontainers.image.version="${VERSION}" \
  org.opencontainers.image.revision="${GIT_SHA}" \
  org.opencontainers.image.title="video-splitter" \
  org.opencontainers.image.description="Split video files into segments for parallel upscaling" \
  org.opencontainers.image.vendor="upscaler"

# Install system dependencies and AWS CLI in single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
  ffmpeg \
  ca-certificates \
  curl \
  unzip \
  && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  && rm -rf awscliv2.zip aws \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get clean

# Create non-root user and required directories
RUN addgroup --system --gid 1001 appgroup && \
  adduser --system --uid 1001 --gid 1001 --no-create-home appuser && \
  mkdir -p /app /work/in /work/out && \
  chown -R appuser:appgroup /app /work

WORKDIR /app

# Install Python dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files in single layer with proper ownership
COPY --chown=appuser:appgroup split_video_exact.py create_manifest.py shot_guidance.py run_split.sh /app/
RUN chmod +x /app/run_split.sh

# Switch to non-root user
USER appuser

# Health check (verifies container can run basic commands)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python3 -c "import boto3; print('healthy')" || exit 1

ENTRYPOINT ["/app/run_split.sh"]
