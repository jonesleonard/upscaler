#!/bin/bash
# shellcheck disable=all
# This is a Terraform templatefile - $$ escaping is intentional
set -euo pipefail

# ============================================================================
# Launch Template User Data - Download SeedVR2 Models
# ============================================================================
# This script runs on EC2 instance launch to pre-download models from S3
# Configure S3 URIs via environment variables or template substitution:
#   DIT_MODEL_S3_URI - S3 URI for DIT model (required)
#   VAE_MODEL_S3_URI - S3 URI for VAE model (required)
#   USE_S5CMD - Set to "true" to use s5cmd for faster downloads (default: false)
# ============================================================================

readonly MODEL_DIR="/opt/seedvr2/models"
readonly LOG_FILE="/var/log/batch-model-download.log"

# Template variables (replaced by Terraform)
readonly DIT_MODEL_S3_URI="${dit_model_s3_uri}"
readonly VAE_MODEL_S3_URI="${vae_model_s3_uri}"
readonly USE_S5CMD="${use_s5cmd}"

log() {
    echo "[$$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $$*" | tee -a "$$LOG_FILE"
}

log_error() {
    echo "[$$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ERROR: $$*" | tee -a "$$LOG_FILE" >&2
}

main() {
    log "============================================================================"
    log "Starting SeedVR2 model download"
    log "============================================================================"
    
    # Validate required variables
    if [[ -z "$$DIT_MODEL_S3_URI" ]]; then
        log_error "DIT_MODEL_S3_URI is not configured"
        exit 1
    fi
    
    if [[ -z "$$VAE_MODEL_S3_URI" ]]; then
        log_error "VAE_MODEL_S3_URI is not configured"
        exit 1
    fi
    
    log "Configuration:"
    log "  MODEL_DIR: $$MODEL_DIR"
    log "  DIT_MODEL_S3_URI: $$DIT_MODEL_S3_URI"
    log "  VAE_MODEL_S3_URI: $$VAE_MODEL_S3_URI"
    log "  USE_S5CMD: $$USE_S5CMD"
    
    # Create model directory
    log "Creating model directory..."
    mkdir -p "$$MODEL_DIR"
    
    # Install AWS CLI if needed
    if ! command -v aws >/dev/null 2>&1; then
        log "Installing AWS CLI..."
        if command -v yum >/dev/null 2>&1; then
            yum install -y awscli
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y awscli
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y awscli
        else
            log_error "Cannot install AWS CLI: unsupported package manager"
            exit 1
        fi
    fi
    
    # Install s5cmd if requested
    if [[ "$$USE_S5CMD" == "true" ]]; then
        if ! command -v s5cmd >/dev/null 2>&1; then
            log "Installing s5cmd for faster downloads..."
            local s5cmd_version="v2.3.0"
            local version_number="2.3.0"
            local tmp_dir
            tmp_dir=$$(mktemp -d)
            
            if curl -fsSL "https://github.com/peak/s5cmd/releases/download/$$s5cmd_version/s5cmd_$${version_number}_Linux-64bit.tar.gz" -o "$$tmp_dir/s5cmd.tar.gz"; then
                tar -xzf "$$tmp_dir/s5cmd.tar.gz" -C "$$tmp_dir"
                mv "$$tmp_dir/s5cmd" /usr/local/bin/s5cmd
                chmod +x /usr/local/bin/s5cmd
                rm -rf "$$tmp_dir"
                log "s5cmd installed successfully"
            else
                log_error "Failed to download s5cmd, falling back to aws cli"
                USE_S5CMD="false"
            fi
        else
            log "s5cmd already installed"
        fi
    fi
    
    # Download DIT model
    log "Downloading DIT model from $$DIT_MODEL_S3_URI..."
    local dit_start
    dit_start=$$(date +%s)
    
    if [[ "$$USE_S5CMD" == "true" ]]; then
        if ! s5cmd cp "$$DIT_MODEL_S3_URI" "$$MODEL_DIR/"; then
            log_error "Failed to download DIT model with s5cmd"
            exit 1
        fi
    else
        if ! aws s3 cp "$$DIT_MODEL_S3_URI" "$$MODEL_DIR/" --only-show-errors; then
            log_error "Failed to download DIT model with aws cli"
            exit 1
        fi
    fi
    
    local dit_end
    dit_end=$$(date +%s)
    log "DIT model downloaded in $$((dit_end - dit_start)) seconds"
    
    # Download VAE model
    log "Downloading VAE model from $$VAE_MODEL_S3_URI..."
    local vae_start
    vae_start=$$(date +%s)
    
    if [[ "$$USE_S5CMD" == "true" ]]; then
        if ! s5cmd cp "$$VAE_MODEL_S3_URI" "$$MODEL_DIR/"; then
            log_error "Failed to download VAE model with s5cmd"
            exit 1
        fi
    else
        if ! aws s3 cp "$$VAE_MODEL_S3_URI" "$$MODEL_DIR/" --only-show-errors; then
            log_error "Failed to download VAE model with aws cli"
            exit 1
        fi
    fi
    
    local vae_end
    vae_end=$$(date +%s)
    log "VAE model downloaded in $$((vae_end - vae_start)) seconds"
    
    # Set permissions
    log "Setting permissions on model directory..."
    chmod -R a+rX "$$MODEL_DIR"
    
    # Verify downloads
    log "Verifying downloads..."
    local file_count
    file_count=$$(find "$$MODEL_DIR" -type f | wc -l | tr -d ' ')
    
    if [[ "$$file_count" -lt 2 ]]; then
        log_error "Expected at least 2 model files, found $$file_count"
        exit 1
    fi
    
    log "Model files in $$MODEL_DIR:"
    find "$$MODEL_DIR" -type f -exec ls -lh {} \; | tee -a "$$LOG_FILE"
    
    log "============================================================================"
    log "SeedVR2 models successfully cached in $$MODEL_DIR"
    log "Total files: $$file_count"
    log "Total download time: $$((vae_end - dit_start)) seconds"
    log "============================================================================"
}

main "$$@"