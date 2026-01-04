# Multi-stage build: Install stage
FROM python:3.11-slim AS builder

# Install pip packages in a virtual environment for better isolation
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir awscli

# Runtime stage: Minimal image
FROM python:3.11-slim

# Install runtime dependencies and clean up in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy Python virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user for security
RUN groupadd -r appgroup && useradd -r -g appgroup -u 1000 appuser \
    && mkdir -p /work/in /work/out \
    && chown -R appuser:appgroup /work

WORKDIR /app

# Copy script with executable permissions
COPY --chmod=755 concat_segments.sh /app/concat_segments.sh

# Switch to non-root user
USER appuser

# Health check to verify container is functional
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=2 \
    CMD command -v ffmpeg && command -v jq && command -v aws || exit 1

ENTRYPOINT ["/app/concat_segments.sh"]