#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Video Upscaler - Upscale a single video segment using SeedVR2
# ============================================================================

readonly WORK_DIR="/work"
readonly INPUT_DIR="${WORK_DIR}/in"
readonly OUTPUT_DIR="${WORK_DIR}/out"
readonly MODEL_DIR="${MODELS_DIR:-/opt/seedvr2/models}"
readonly INPUT_FILE="${INPUT_DIR}/segment.mp4"
readonly AUDIO_FILE="${INPUT_DIR}/audio.aac"
readonly OUTPUT_FILE_NO_AUDIO="${OUTPUT_DIR}/segment_no_audio.mp4"
readonly OUTPUT_FILE="${OUTPUT_DIR}/segment.mp4"

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "============================================================================"
        echo "ERROR: Script failed with exit code $exit_code"
        echo "============================================================================"
    fi
    # Cleanup work directory
    if [[ -d "$WORK_DIR" ]]; then
        echo "Cleaning up work directory..."
        rm -rf "${INPUT_DIR:?}"/* "${OUTPUT_DIR:?}"/* 2>/dev/null || true
    fi
}

trap cleanup EXIT

log_info() {
    echo "[INFO] $(date -u +"%Y-%m-%dT%H:%M:%SZ") $*"
}

log_error() {
    echo "[ERROR] $(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" >&2
}

log_metric() {
    local metric_name=$1
    local metric_value=$2
    echo "[METRIC] $(date -u +"%Y-%m-%dT%H:%M:%SZ") ${metric_name}=${metric_value}"
}

validate_requirements() {
    log_info "Validating requirements..."
    
    # Check required commands
    local required_commands=(aws python3 ffmpeg)
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Validate required environment variables
    if [[ -z "${INPUT_SEGMENT_S3_URI:-}" ]]; then
        log_error "INPUT_SEGMENT_S3_URI is required (e.g., s3://bucket/segments/EXEC123/raw/seg_0003.mp4)"
        exit 1
    fi
    
    if [[ -z "${OUTPUT_SEGMENT_S3_URI:-}" ]]; then
        log_error "OUTPUT_SEGMENT_S3_URI is required (e.g., s3://bucket/segments/EXEC123/upscaled/seg_0003_up.mp4)"
        exit 1
    fi
    
    # Validate S3 URI format
    if [[ ! "$INPUT_SEGMENT_S3_URI" =~ ^s3:// ]]; then
        log_error "INPUT_SEGMENT_S3_URI must start with s3:// - got: $INPUT_SEGMENT_S3_URI"
        exit 1
    fi
    
    if [[ ! "$OUTPUT_SEGMENT_S3_URI" =~ ^s3:// ]]; then
        log_error "OUTPUT_SEGMENT_S3_URI must start with s3:// - got: $OUTPUT_SEGMENT_S3_URI"
        exit 1
    fi
    
    # Validate inference_cli.py is available
    if ! python3 -c "import sys; sys.path.insert(0, '/opt/seedvr2'); import inference_cli" 2>/dev/null; then
        log_error "SeedVR2 inference_cli module not found. Check installation."
        exit 1
    fi
    
    # Validate 10-bit encoding requirements
    if [[ "${TEN_BIT:-false}" == "true" ]]; then
        if [[ "${VIDEO_BACKEND:-opencv}" != "ffmpeg" ]]; then
            log_error "10-bit encoding requires VIDEO_BACKEND=ffmpeg"
            log_error "Current VIDEO_BACKEND: ${VIDEO_BACKEND:-opencv}"
            log_error "Please set VIDEO_BACKEND=ffmpeg when using TEN_BIT=true"
            exit 1
        fi
        
        # Verify ffmpeg is available on PATH
        if ! command -v ffmpeg &> /dev/null; then
            log_error "10-bit encoding requires ffmpeg but ffmpeg is not available on PATH"
            log_error "Please install ffmpeg or disable TEN_BIT"
            exit 1
        fi
        
        log_info "10-bit encoding validated (VIDEO_BACKEND=ffmpeg, ffmpeg available)"
    fi
    
    # Validate torch.compile requirements
    if [[ "${COMPILE_DIT:-false}" == "true" || "${COMPILE_VAE:-false}" == "true" ]]; then
        # Check PyTorch version
        local pytorch_version
        pytorch_version=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
        if [[ "$pytorch_version" == "unknown" ]]; then
            log_error "torch.compile requires PyTorch but PyTorch is not installed"
            exit 1
        fi
        
        # Check PyTorch version is >= 2.0
        local major_version
        major_version=$(echo "$pytorch_version" | cut -d. -f1)
        if [[ "$major_version" -lt 2 ]]; then
            log_error "torch.compile requires PyTorch >= 2.0"
            log_error "Current PyTorch version: $pytorch_version"
            log_error "Please upgrade PyTorch or disable COMPILE_DIT and COMPILE_VAE"
            exit 1
        fi
        
        # Check torch.compile is available
        if ! python3 -c "import torch; assert hasattr(torch, 'compile')" 2>/dev/null; then
            log_error "torch.compile is not available in PyTorch $pytorch_version"
            log_error "Please upgrade PyTorch or disable COMPILE_DIT and COMPILE_VAE"
            exit 1
        fi
        
        # Check Triton is available
        if ! python3 -c "import triton" 2>/dev/null; then
            log_error "torch.compile requires Triton but Triton is not installed"
            log_error "Please install Triton or disable COMPILE_DIT and COMPILE_VAE"
            exit 1
        fi
        
        local triton_version
        triton_version=$(python3 -c "import triton; print(triton.__version__)" 2>/dev/null || echo "unknown")
        log_info "torch.compile validated (PyTorch $pytorch_version, Triton $triton_version)"
    fi
    
    log_info "All requirements validated"
}

main() {
    # Set defaults for SeedVR2 parameters
    readonly DEBUG="${DEBUG:-false}"
    readonly SEED="${SEED:-42}"
    readonly COLOR_CORRECTION="${COLOR_CORRECTION:-lab}"
    readonly MODEL="${MODEL:-7b}"
    readonly RESOLUTION="${RESOLUTION:-1080}"
    readonly CHUNK_SIZE="${CHUNK_SIZE:-}"
    readonly ATTENTION_MODE="${ATTENTION_MODE:-}"
    readonly TEMPORAL_OVERLAP="${TEMPORAL_OVERLAP:-}"
    readonly VAE_ENCODE_TILED="${VAE_ENCODE_TILED:-}"
    readonly VAE_DECODE_TILED="${VAE_DECODE_TILED:-}"
    readonly CACHE_DIT="${CACHE_DIT:-}"
    readonly CACHE_VAE="${CACHE_VAE:-}"
    readonly VIDEO_BACKEND="${VIDEO_BACKEND:-opencv}"
    readonly TEN_BIT="${TEN_BIT:-false}"
    readonly COMPILE_DIT="${COMPILE_DIT:-false}"
    readonly COMPILE_VAE="${COMPILE_VAE:-false}"
    
    # Batch size strategy: "conservative", "quality", or "explicit"
    readonly BATCH_SIZE_STRATEGY="${BATCH_SIZE_STRATEGY:-explicit}"
    readonly BATCH_SIZE_EXPLICIT="${BATCH_SIZE_EXPLICIT:-129}"
    readonly BATCH_SIZE_CONSERVATIVE="${BATCH_SIZE_CONSERVATIVE:-}"
    readonly BATCH_SIZE_QUALITY="${BATCH_SIZE_QUALITY:-}"
    
    # Resolve batch_size based on strategy
    local batch_size
    case "$BATCH_SIZE_STRATEGY" in
        conservative)
            if [[ -n "$BATCH_SIZE_CONSERVATIVE" && "$BATCH_SIZE_CONSERVATIVE" != "null" ]]; then
                batch_size="$BATCH_SIZE_CONSERVATIVE"
            else
                log_error "BATCH_SIZE_STRATEGY=conservative but BATCH_SIZE_CONSERVATIVE not provided"
                exit 1
            fi
            ;;
        quality)
            if [[ -n "$BATCH_SIZE_QUALITY" && "$BATCH_SIZE_QUALITY" != "null" ]]; then
                batch_size="$BATCH_SIZE_QUALITY"
            else
                log_error "BATCH_SIZE_STRATEGY=quality but BATCH_SIZE_QUALITY not provided"
                exit 1
            fi
            ;;
        explicit|*)
            batch_size="$BATCH_SIZE_EXPLICIT"
            ;;
    esac
    readonly BATCH_SIZE="$batch_size"

    # Chunk size strategy: "recommended", "fallback", or "explicit"
    readonly CHUNK_SIZE_STRATEGY="${CHUNK_SIZE_STRATEGY:-explicit}"
    readonly CHUNK_SIZE_EXPLICIT="${CHUNK_SIZE_EXPLICIT:-}"
    readonly CHUNK_SIZE_RECOMMENDED="${CHUNK_SIZE_RECOMMENDED:-}"
    readonly CHUNK_SIZE_FALLBACK="${CHUNK_SIZE_FALLBACK:-}"

    # Resolve chunk_size based on strategy
    local chunk_size
    case "$CHUNK_SIZE_STRATEGY" in
        recommended)
            if [[ -n "$CHUNK_SIZE_RECOMMENDED" && "$CHUNK_SIZE_RECOMMENDED" != "null" ]]; then
                chunk_size="$CHUNK_SIZE_RECOMMENDED"
            else
                log_error "CHUNK_SIZE_STRATEGY=recommended but CHUNK_SIZE_RECOMMENDED not provided"
                exit 1
            fi
            ;;
        fallback)
            if [[ -n "$CHUNK_SIZE_FALLBACK" && "$CHUNK_SIZE_FALLBACK" != "null" ]]; then
                chunk_size="$CHUNK_SIZE_FALLBACK"
            else
                log_error "CHUNK_SIZE_STRATEGY=fallback but CHUNK_SIZE_FALLBACK not provided"
                exit 1
            fi
            ;;
        explicit|*)
            chunk_size="$CHUNK_SIZE_EXPLICIT"
            ;;
    esac
    readonly CHUNK_SIZE="$chunk_size"
    
    echo "============================================================================"
    echo "Video Upscaler - Starting"
    echo "============================================================================"
    log_info "Configuration:"
    log_info "  INPUT_SEGMENT_S3_URI: $INPUT_SEGMENT_S3_URI"
    log_info "  OUTPUT_SEGMENT_S3_URI: $OUTPUT_SEGMENT_S3_URI"
    log_info "  DEBUG: $DEBUG"
    log_info "  SEED: $SEED"
    log_info "  COLOR_CORRECTION: $COLOR_CORRECTION"
    log_info "  MODEL: $MODEL"
    log_info "  RESOLUTION: $RESOLUTION"
    log_info "  BATCH_SIZE_STRATEGY: $BATCH_SIZE_STRATEGY"
    log_info "  BATCH_SIZE: $BATCH_SIZE (resolved)"
    log_info "  CHUNK_SIZE_STRATEGY: $CHUNK_SIZE_STRATEGY"
    [[ -n "$CHUNK_SIZE" ]] && log_info "  CHUNK_SIZE: $CHUNK_SIZE (resolved)"
    [[ -n "$ATTENTION_MODE" ]] && log_info "  ATTENTION_MODE: $ATTENTION_MODE"
    [[ -n "$TEMPORAL_OVERLAP" ]] && log_info "  TEMPORAL_OVERLAP: $TEMPORAL_OVERLAP"
    [[ -n "$VAE_ENCODE_TILED" ]] && log_info "  VAE_ENCODE_TILED: $VAE_ENCODE_TILED"
    [[ -n "$VAE_DECODE_TILED" ]] && log_info "  VAE_DECODE_TILED: $VAE_DECODE_TILED"
    [[ -n "$CACHE_DIT" ]] && log_info "  CACHE_DIT: $CACHE_DIT"
    [[ -n "$CACHE_VAE" ]] && log_info "  CACHE_VAE: $CACHE_VAE"
    log_info "  VIDEO_BACKEND: $VIDEO_BACKEND"
    [[ "$TEN_BIT" == "true" ]] && log_info "  TEN_BIT: $TEN_BIT"
    [[ "$COMPILE_DIT" == "true" ]] && log_info "  COMPILE_DIT: $COMPILE_DIT"
    [[ "$COMPILE_VAE" == "true" ]] && log_info "  COMPILE_VAE: $COMPILE_VAE"
    echo "============================================================================"
    
    validate_requirements
    
    # Create work directories
    log_info "Creating work directories..."
    mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"
    
    # Validate model directory exists and log path
    if [[ ! -d "$MODEL_DIR" ]]; then
        log_error "Model directory does not exist: $MODEL_DIR"
        log_error "Ensure your mounted volume is present at this path."
        exit 1
    fi
    log_info "Model directory: $MODEL_DIR"
    
    # Check models exist locally (pre-populated via launch template user-data)
    local model_count
    model_count=$(find "$MODEL_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$model_count" -eq 0 ]]; then
        log_error "No models found at $MODEL_DIR"
        log_error "Models must be present before running jobs (download in launch template user-data)."
        exit 1
    fi
    
    log_info "Using models from $MODEL_DIR ($model_count files found)"
    log_metric "model_file_count" "$model_count"
    
    # Download input segment
    log_info "Downloading input segment from S3..."
    local download_start
    download_start=$(date +%s)
    
    if ! aws s3 cp "$INPUT_SEGMENT_S3_URI" "$INPUT_FILE"; then
        log_error "Failed to download input segment from: $INPUT_SEGMENT_S3_URI"
        exit 1
    fi
    
    local download_end
    download_end=$(date +%s)
    local download_duration=$((download_end - download_start))
    log_info "Input downloaded in ${download_duration} seconds"
    log_metric "input_download_duration_seconds" "$download_duration"
    
    # Verify file was downloaded
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file does not exist after download: $INPUT_FILE"
        exit 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null || echo "unknown")
    log_info "Downloaded segment file size: ${file_size} bytes"
    log_metric "input_segment_size_bytes" "$file_size"
    
    # Extract audio from input video (if present)
    log_info "Extracting audio from input video..."
    local has_audio=false
    if ffmpeg -i "$INPUT_FILE" -t 1 -f null - 2>&1 | grep -q "Audio:"; then
        log_info "Audio stream detected, extracting..."
        if ffmpeg -i "$INPUT_FILE" -vn -acodec copy "$AUDIO_FILE" -y -loglevel error; then
            has_audio=true
            local audio_size
            audio_size=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "0")
            log_info "Audio extracted: ${audio_size} bytes"
            log_metric "has_audio" "true"
        else
            log_error "Failed to extract audio, will proceed without it"
            has_audio=false
            log_metric "has_audio" "false"
        fi
    else
        log_info "No audio stream found in input video"
        log_metric "has_audio" "false"
    fi
    
    # Run SeedVR2 upscaling
    log_info "Starting SeedVR2 upscaling..."
    local start_time
    start_time=$(date +%s)
    
    # Build inference command with optional parameters
    local inference_cmd=(
        python3 /opt/seedvr2/inference_cli.py "$INPUT_FILE"
        --output "$OUTPUT_DIR"
        --model_dir "$MODEL_DIR"
        --dit_model "$MODEL"
        --resolution "$RESOLUTION"
        --batch_size "$BATCH_SIZE"
        --seed "$SEED"
        --color_correction "$COLOR_CORRECTION"
    )
    
    # Add optional parameters if set
    [[ "$DEBUG" == "true" ]] && inference_cmd+=(--debug)
    [[ -n "$ATTENTION_MODE" ]] && inference_cmd+=(--attention_mode "$ATTENTION_MODE")
    [[ -n "$CHUNK_SIZE" ]] && inference_cmd+=(--chunk_size "$CHUNK_SIZE")
    [[ -n "$TEMPORAL_OVERLAP" ]] && inference_cmd+=(--temporal_overlap "$TEMPORAL_OVERLAP")
    [[ "$VAE_ENCODE_TILED" == "true" ]] && inference_cmd+=(--vae_encode_tiled)
    [[ "$VAE_DECODE_TILED" == "true" ]] && inference_cmd+=(--vae_decode_tiled)
    [[ "$CACHE_DIT" == "true" ]] && inference_cmd+=(--cache_dit)
    [[ "$CACHE_VAE" == "true" ]] && inference_cmd+=(--cache_vae)
    [[ -n "$VIDEO_BACKEND" ]] && inference_cmd+=(--video_backend "$VIDEO_BACKEND")
    [[ "$TEN_BIT" == "true" ]] && inference_cmd+=(--10bit)
    [[ "$COMPILE_DIT" == "true" ]] && inference_cmd+=(--compile_dit)
    [[ "$COMPILE_VAE" == "true" ]] && inference_cmd+=(--compile_vae)
    
    if ! "${inference_cmd[@]}"; then
        log_error "SeedVR2 upscaling failed"
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "Upscaling completed in ${duration} seconds"
    log_metric "upscale_duration_seconds" "$duration"
    
    # The upscaled video is now at OUTPUT_FILE (video only, no audio)
    # Verify output file was created
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        log_error "Output file was not created: $OUTPUT_FILE"
        exit 1
    fi
    
    # If we extracted audio, merge it back with the upscaled video
    if [[ "$has_audio" == "true" ]]; then
        log_info "Merging audio back into upscaled video..."
        local merge_start
        merge_start=$(date +%s)
        
        # Move the video-only output to temporary location
        mv "$OUTPUT_FILE" "$OUTPUT_FILE_NO_AUDIO"
        
        # Merge video and audio
        if ! ffmpeg -i "$OUTPUT_FILE_NO_AUDIO" -i "$AUDIO_FILE" \
            -c:v copy -c:a aac -shortest \
            "$OUTPUT_FILE" -y -loglevel error; then
            log_error "Failed to merge audio with upscaled video"
            # Fallback: use video-only output
            mv "$OUTPUT_FILE_NO_AUDIO" "$OUTPUT_FILE"
            log_info "Continuing with video-only output"
        else
            local merge_end
            merge_end=$(date +%s)
            local merge_duration=$((merge_end - merge_start))
            log_info "Audio merged in ${merge_duration} seconds"
            log_metric "audio_merge_duration_seconds" "$merge_duration"
            # Clean up temporary file
            rm -f "$OUTPUT_FILE_NO_AUDIO"
        fi
    fi
    
    local output_size
    output_size=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
    log_info "Output segment file size: ${output_size} bytes"
    log_metric "output_segment_size_bytes" "$output_size"
    
    # Upload upscaled segment to S3
    log_info "Uploading upscaled segment to S3..."
    local upload_start
    upload_start=$(date +%s)
    
    if ! aws s3 cp "$OUTPUT_FILE" "$OUTPUT_SEGMENT_S3_URI" --sse AES256; then
        log_error "Failed to upload segment to: $OUTPUT_SEGMENT_S3_URI"
        exit 1
    fi
    
    local upload_end
    upload_end=$(date +%s)
    local upload_duration=$((upload_end - upload_start))
    log_info "Output uploaded in ${upload_duration} seconds"
    log_metric "output_upload_duration_seconds" "$upload_duration"
    
    echo "============================================================================"
    echo "✅ Video upscaling completed successfully"
    echo "============================================================================"
    log_info "Summary:"
    log_info "  Processing time: ${duration}s"
    log_info "  Input size: ${file_size} bytes"
    log_info "  Output size: ${output_size} bytes"
    log_info "  Output location: $OUTPUT_SEGMENT_S3_URI"
    log_metric "job_status" "success"
    echo "============================================================================"
}

main "$@"