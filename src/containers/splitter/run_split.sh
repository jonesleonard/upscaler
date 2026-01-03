#!/usr/bin/env bash

# ============================================================================
# Video Splitter - Split video into segments and upload to S3
# ============================================================================

set -euo pipefail

# Configuration constants
readonly WORK_DIR="/work"
readonly INPUT_DIR="${WORK_DIR}/in"
readonly OUTPUT_DIR="${WORK_DIR}/out"
readonly INPUT_FILE="${INPUT_DIR}/input.mp4"

# Retry configuration
readonly MAX_RETRIES="${MAX_RETRIES:-3}"
readonly INITIAL_BACKOFF_SECONDS="${INITIAL_BACKOFF_SECONDS:-2}"

# Track upload state for cleanup
UPLOAD_STARTED="false"
UPLOAD_COMPLETED="false"

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    echo "[INFO] $(date -u +"%Y-%m-%dT%H:%M:%SZ") $*"
}

log_error() {
    echo "[ERROR] $(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" >&2
}

log_warn() {
    echo "[WARN] $(date -u +"%Y-%m-%dT%H:%M:%SZ") $*" >&2
}

log_metric() {
    # Structured log for metrics - easier to parse in CloudWatch Insights
    local metric_name=$1
    local metric_value=$2
    echo "[METRIC] $(date -u +"%Y-%m-%dT%H:%M:%SZ") ${metric_name}=${metric_value}"
}

# ============================================================================
# Retry Logic with Exponential Backoff
# ============================================================================

retry_with_backoff() {
    # Usage: retry_with_backoff <description> <command> [args...]
    # Example: retry_with_backoff "downloading video" aws s3 cp s3://bucket/file ./file
    local description=$1
    shift
    local attempt=1
    local backoff=$INITIAL_BACKOFF_SECONDS
    local output
    local exit_code

    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_info "Attempt $attempt/$MAX_RETRIES: $description"

        # Capture both stdout and stderr, preserve exit code
        set +e
        output=$("$@" 2>&1)
        exit_code=$?
        set -e

        if [[ $exit_code -eq 0 ]]; then
            if [[ -n "$output" ]]; then
                echo "$output"
            fi
            return 0
        fi

        log_warn "Attempt $attempt failed (exit code $exit_code): $description"
        if [[ -n "$output" ]]; then
            log_warn "Command output: $output"
        fi

        if [[ $attempt -lt $MAX_RETRIES ]]; then
            log_info "Retrying in ${backoff}s..."
            sleep "$backoff"
            backoff=$((backoff * 2))
        fi

        ((attempt++))
    done

    log_error "All $MAX_RETRIES attempts failed: $description"
    if [[ -n "$output" ]]; then
        log_error "Last error output: $output"
    fi
    return 1
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo "============================================================================"
        echo "ERROR: Script failed with exit code $exit_code"
        echo "============================================================================"

        # Clean up partial S3 uploads if upload started but not completed
        if [[ "$UPLOAD_STARTED" == "true" && "$UPLOAD_COMPLETED" != "true" ]]; then
            log_warn "Cleaning up partial S3 uploads..."
            if [[ -n "${OUTPUT_S3_PREFIX:-}" ]]; then
                # Attempt to remove partial uploads (best effort, don't fail on error)
                aws s3 rm "${OUTPUT_S3_PREFIX}/raw/" --recursive 2>/dev/null || true
                log_warn "Partial S3 cleanup attempted for: ${OUTPUT_S3_PREFIX}/raw/"
            fi
        fi

        log_metric "job_status" "failed"
    fi

    # Cleanup work directory
    if [[ -d "$WORK_DIR" ]]; then
        log_info "Cleaning up work directory..."
        rm -rf "${INPUT_DIR:?}"/* "${OUTPUT_DIR:?}"/* 2>/dev/null || true
    fi
}

trap cleanup EXIT

# ============================================================================
# Validation Functions
# ============================================================================

validate_requirements() {
    log_info "Validating requirements..."

    # Check required commands
    local required_commands=(aws python3 ffmpeg ffprobe)
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Validate required environment variables
    if [[ -z "${INPUT_S3_URI:-}" ]]; then
        log_error "INPUT_S3_URI is required (e.g., s3://bucket/input/video.mp4)"
        exit 1
    fi

    if [[ -z "${OUTPUT_S3_PREFIX:-}" ]]; then
        log_error "OUTPUT_S3_PREFIX is required (e.g., s3://bucket/segments/EXEC123)"
        exit 1
    fi

    if [[ -z "${MANIFEST_KEY:-}" ]]; then
        log_error "MANIFEST_KEY is required (e.g., s3://bucket/segments/EXEC123/manifest.json)"
        exit 1
    fi

    # Validate S3 URI format
    if [[ ! "$INPUT_S3_URI" =~ ^s3:// ]]; then
        log_error "INPUT_S3_URI must start with s3:// - got: $INPUT_S3_URI"
        exit 1
    fi

    if [[ ! "$OUTPUT_S3_PREFIX" =~ ^s3:// ]]; then
        log_error "OUTPUT_S3_PREFIX must start with s3:// - got: $OUTPUT_S3_PREFIX"
        exit 1
    fi

    if [[ ! "$MANIFEST_KEY" =~ ^s3:// ]]; then
        log_error "MANIFEST_KEY must start with s3:// - got: $MANIFEST_KEY"
        exit 1
    fi

    log_info "All requirements validated"
}

# ============================================================================
# Download Function
# ============================================================================

download_input_video() {
    log_info "Downloading input video from S3..."

    if ! retry_with_backoff "downloading input video" aws s3 cp "$INPUT_S3_URI" "$INPUT_FILE"; then
        log_error "Failed to download input video from: $INPUT_S3_URI"
        exit 1
    fi

    # Verify file was downloaded
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file does not exist after download: $INPUT_FILE"
        exit 1
    fi

    local file_size
    file_size=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null || echo "unknown")
    log_info "Downloaded video file size: ${file_size} bytes"
    log_metric "input_file_size_bytes" "$file_size"

    # Validate it's a video file (basic check)
    if ! ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$INPUT_FILE" &>/dev/null; then
        log_error "Downloaded file is not a valid video: $INPUT_FILE"
        exit 1
    fi

    log_info "Input video validated successfully"
}

# ============================================================================
# Split Function
# ============================================================================

split_video() {
    local chunk_seconds="${CHUNK_SECONDS:-300}"
    local use_stream_copy="${USE_STREAM_COPY:-true}"
    local a_codec="${A_CODEC:-aac}"
    local a_bitrate="${A_BITRATE:-192k}"
    local v_codec="${V_CODEC:-libx264}"

    log_info "Splitting video into ${chunk_seconds}-second segments..."

    local split_args=("$INPUT_FILE" --seconds "$chunk_seconds" --outdir "$OUTPUT_DIR")

    if [[ "$use_stream_copy" == "true" ]]; then
        log_info "Using stream copy mode (fast, no re-encoding)"
        split_args+=(--stream-copy)
    else
        log_info "Using re-encode mode (precise, slower)"
        split_args+=(--vcodec "$v_codec" --acodec "$a_codec" --abitrate "$a_bitrate")
    fi

    if ! python3 /app/split_video_exact.py "${split_args[@]}"; then
        log_error "Failed to split video"
        exit 1
    fi

    # Count generated segments
    local segment_count
    segment_count=$(find "$OUTPUT_DIR" -name "seg_*.mp4" -type f | wc -l | tr -d ' ')
    log_metric "segment_count" "$segment_count"
    log_info "Generated $segment_count video segments"

    if [[ "$segment_count" -eq 0 ]]; then
        log_error "No segments were generated"
        exit 1
    fi

    echo "$segment_count"
}

# ============================================================================
# Upload Functions
# ============================================================================

upload_segments() {
    log_info "Uploading segments to S3..."
    UPLOAD_STARTED="true"

    local output
    if ! output=$(aws s3 cp "$OUTPUT_DIR/" "${OUTPUT_S3_PREFIX}/raw/" \
        --recursive \
        --exclude "*" \
        --include "seg_*.mp4" \
        --sse AES256 2>&1); then
        log_error "Failed to upload segments to: ${OUTPUT_S3_PREFIX}/raw/"
        log_error "AWS CLI output: $output"
        exit 1
    fi

    # Verify upload
    local uploaded_count
    uploaded_count=$(aws s3 ls "${OUTPUT_S3_PREFIX}/raw/" 2>/dev/null | grep -c "seg_.*\.mp4" || echo "0")
    log_info "Verified $uploaded_count segments uploaded to S3"

    if [[ "$uploaded_count" -eq 0 ]]; then
        log_error "No segments found in S3 after upload"
        exit 1
    fi

    log_info "Segment upload completed successfully"
}

upload_manifest() {
    log_info "Uploading manifest to S3..."

    local output
    if ! output=$(aws s3 cp "${OUTPUT_DIR}/manifest.json" "${MANIFEST_KEY}" --sse AES256 2>&1); then
        log_error "Failed to upload manifest to: ${MANIFEST_KEY}"
        log_error "AWS CLI output: $output"
        exit 1
    fi

    UPLOAD_COMPLETED="true"
    log_info "Manifest uploaded successfully"
}

# ============================================================================
# Shot Guidance Analysis
# ============================================================================

analyze_shot_guidance() {
    log_info "Analyzing video for shot guidance..."

    # Verify shot_guidance.py exists
    if [[ ! -f "/app/shot_guidance.py" ]]; then
        log_warn "Shot guidance script not found at /app/shot_guidance.py"
        echo ""
        return
    fi

    local shot_guidance_json=""
    local output
    local exit_code

    set +e
    output=$(python3 /app/shot_guidance.py "$INPUT_FILE" \
        --scene-threshold "${SCENE_THRESHOLD:-0.30}" \
        --json 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
        shot_guidance_json="$output"
        log_info "Shot guidance analysis completed successfully"
    else
        # Shot guidance failure is non-fatal but should be explicitly logged
        log_warn "Shot guidance analysis failed (exit code: $exit_code)"
        log_warn "Error output: $output"
        log_warn "Input file: $INPUT_FILE"
        log_warn "Scene threshold: ${SCENE_THRESHOLD:-0.30}"
        log_warn "Manifest will be created without shot guidance metadata"
    fi

    echo "$shot_guidance_json"
}

# ============================================================================
# Manifest Creation
# ============================================================================

create_manifest() {
    local shot_guidance_json=$1

    log_info "Creating manifest file..."

    # Use null if shot_guidance_json is empty
    local shot_guidance_value="${shot_guidance_json:-null}"

    if ! env OUTPUT_DIR="$OUTPUT_DIR" \
             OUTPUT_S3_PREFIX="$OUTPUT_S3_PREFIX" \
             CHUNK_SECONDS="${CHUNK_SECONDS:-300}" \
             SHOT_GUIDANCE_JSON="$shot_guidance_value" \
             python3 /app/create_manifest.py; then
        log_error "Failed to create manifest"
        exit 1
    fi

    # Verify manifest exists
    if [[ ! -f "${OUTPUT_DIR}/manifest.json" ]]; then
        log_error "Manifest file was not created: ${OUTPUT_DIR}/manifest.json"
        exit 1
    fi

    log_info "Manifest created successfully"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    echo "============================================================================"
    echo "Video Splitter - Starting"
    echo "============================================================================"

    log_info "Configuration:"
    log_info "  INPUT_S3_URI: ${INPUT_S3_URI:-<not set>}"
    log_info "  OUTPUT_S3_PREFIX: ${OUTPUT_S3_PREFIX:-<not set>}"
    log_info "  MANIFEST_KEY: ${MANIFEST_KEY:-<not set>}"
    log_info "  CHUNK_SECONDS: ${CHUNK_SECONDS:-300}"
    log_info "  USE_STREAM_COPY: ${USE_STREAM_COPY:-true}"
    log_info "  VIDEO_CODEC: ${V_CODEC:-h264}"
    log_info "  AUDIO_CODEC: ${A_CODEC:-aac}"
    log_info "  AUDIO_BITRATE: ${A_BITRATE:-192k}"
    log_info "  SCENE_THRESHOLD: ${SCENE_THRESHOLD:-0.30}"
    log_info "  MAX_RETRIES: ${MAX_RETRIES}"

    echo "============================================================================"

    validate_requirements

    # Create work directories
    log_info "Creating work directories..."
    mkdir -p "$INPUT_DIR" "$OUTPUT_DIR"

    # Step 1: Download input video
    download_input_video

    # Step 2: Split video into segments
    local segment_count
    segment_count=$(split_video)

    # Step 3: Upload segments to S3
    upload_segments

    # Step 4: Analyze video for shot guidance (non-fatal if fails)
    local shot_guidance_json
    shot_guidance_json=$(analyze_shot_guidance)

    # Step 5: Create manifest
    create_manifest "$shot_guidance_json"

    # Step 6: Upload manifest
    upload_manifest

    echo "============================================================================"
    echo "✅ Video splitting completed successfully"
    echo "============================================================================"

    log_info "Summary:"
    log_info "  Segments generated: $segment_count"
    log_info "  Output location: ${OUTPUT_S3_PREFIX}"
    log_info "  Manifest: ${MANIFEST_KEY}"
    log_metric "job_status" "success"

    echo "============================================================================"
}

main "$@"
