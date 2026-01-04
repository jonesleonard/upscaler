#!/usr/bin/env bash

# ============================================================================
# Video Segment Combiner
# Downloads upscaled video segments from S3 and concatenates them into a
# single output video using ffmpeg.
# ============================================================================

set -euo pipefail

readonly WORK_IN="/work/in"
readonly WORK_OUT="/work/out"
readonly MANIFEST_FILE="${WORK_IN}/manifest.json"
readonly SEGMENT_NAMES_FILE="${WORK_IN}/segment_names.txt"
readonly CONCAT_LIST_FILE="${WORK_IN}/concat.txt"
readonly OUTPUT_FILE="${WORK_OUT}/final.mp4"
readonly EXEC_ID="${AWS_BATCH_JOB_ID:-local-$(date +%s)}"
START_TIME=$(date +%s)
readonly START_TIME

log() {
    local level="$1"
    shift
    local elapsed=$(($(date +%s) - START_TIME))
    printf "[%s] [exec_id=%s] [elapsed=%ds] %s\n" "$level" "$EXEC_ID" "$elapsed" "$*"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@" >&2
}

log_debug() {
    log "DEBUG" "$@"
}

check_requirements() {
    log_info "Checking required dependencies"
    
    local missing_deps=()
    local required_deps=("aws" "jq" "ffmpeg")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log_debug "All required dependencies available"
}

cleanup() {
    if [[ -n "${WORK_IN:-}" && -d "$WORK_IN" ]]; then
        log_debug "Cleaning up temporary workspace: $WORK_IN"
        rm -rf "$WORK_IN"
    fi
}

validate_environment() {
    if [[ -z "${MANIFEST_S3_URI:-}" ]]; then
        log_error "MANIFEST_S3_URI is required (e.g., s3://bucket/segments/EXEC123/manifest.json)"
        exit 1
    fi
    
    if [[ -z "${UPSCALED_S3_PREFIX:-}" ]]; then
        log_error "UPSCALED_S3_PREFIX is required (e.g., s3://bucket/segments/EXEC123/upscaled/)"
        exit 1
    fi
    
    if [[ -z "${OUTPUT_FINAL_S3_URI:-}" ]]; then
        log_error "OUTPUT_FINAL_S3_URI is required (e.g., s3://bucket/output/EXEC123/final.mp4)"
        exit 1
    fi
    
    log_info "Environment validated - manifest=$MANIFEST_S3_URI upscaled_prefix=$UPSCALED_S3_PREFIX output=$OUTPUT_FINAL_S3_URI"
}

prepare_workspace() {
    log_info "Preparing workspace directories"
    mkdir -p "$WORK_IN" "$WORK_OUT"
}

download_manifest() {
    log_info "Downloading manifest from S3"
    if ! aws s3 cp "$MANIFEST_S3_URI" "$MANIFEST_FILE" 2>&1; then
        log_error "Failed to download manifest from $MANIFEST_S3_URI"
        exit 1
    fi
    
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Manifest file not found after download: $MANIFEST_FILE"
        exit 1
    fi
    
    log_debug "Manifest downloaded successfully"
}

extract_segment_names() {
    log_info "Extracting segment names from manifest"
    
    # Validate JSON structure
    if ! jq -e '.segments' "$MANIFEST_FILE" > /dev/null 2>&1; then
        log_error "Invalid manifest format: missing 'segments' field"
        exit 1
    fi
    
    local segment_count
    segment_count=$(jq -r '.segments | length' "$MANIFEST_FILE")
    
    if [[ "$segment_count" -eq 0 ]]; then
        log_error "No segments found in manifest"
        exit 1
    fi
    
    log_info "Found segment_count=$segment_count segments to process"
    
    # Extract filenames as-is (upscaler uses same filename)
    jq -r '.segments[].filename' "$MANIFEST_FILE" > "$SEGMENT_NAMES_FILE"
    
    log_debug "Segment names extracted successfully"
}

download_segments() {
    log_info "Downloading upscaled segments from S3"
    
    local total_segments
    total_segments=$(wc -l < "$SEGMENT_NAMES_FILE")
    local current=0
    
    while IFS= read -r name; do
        current=$((current + 1))
        log_info "Downloading segment progress=$current/$total_segments name=$name"
        
        local s3_uri="${UPSCALED_S3_PREFIX}/${name}"
        local local_path="${WORK_IN}/${name}"
        
        if ! aws s3 cp "$s3_uri" "$local_path" 2>&1; then
            log_error "Failed to download segment: $s3_uri"
            exit 1
        fi
        
        if [[ ! -f "$local_path" ]]; then
            log_error "Segment file not found after download: $local_path"
            exit 1
        fi
    done < "$SEGMENT_NAMES_FILE"
    
    log_info "All segments downloaded successfully count=$total_segments"
}

create_concat_list() {
    log_info "Creating ffmpeg concat list"
    
    rm -f "$CONCAT_LIST_FILE"
    
    while IFS= read -r name; do
        echo "file '${WORK_IN}/${name}'" >> "$CONCAT_LIST_FILE"
    done < "$SEGMENT_NAMES_FILE"
    
    local line_count
    line_count=$(wc -l < "$CONCAT_LIST_FILE")
    log_debug "Concat list created with entry_count=$line_count"
}

concatenate_segments() {
    log_info "Concatenating segments with ffmpeg using stream copy"
    
    # Use -loglevel warning to only show warnings/errors, reducing CloudWatch noise
    if ! ffmpeg -hide_banner -loglevel warning -y \
        -f concat -safe 0 -i "$CONCAT_LIST_FILE" \
        -c copy \
        "$OUTPUT_FILE" 2>&1; then
        log_error "ffmpeg concatenation failed"
        exit 1
    fi
    
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        log_error "Output file not created: $OUTPUT_FILE"
        exit 1
    fi
    
    local output_size output_bytes
    output_size=$(du -h "$OUTPUT_FILE" | cut -f1)
    output_bytes=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "0")
    log_info "Video concatenation complete output_size=$output_size output_bytes=$output_bytes"
}

upload_output() {
    log_info "Uploading final output to S3"
    
    if ! aws s3 cp "$OUTPUT_FILE" "$OUTPUT_FINAL_S3_URI" \
        --sse AES256 2>&1; then
        log_error "Failed to upload output to $OUTPUT_FINAL_S3_URI"
        exit 1
    fi
    
    log_info "Upload complete destination=$OUTPUT_FINAL_S3_URI"
}
main() {
    echo "============================================================================"
    echo "Video Segment Combiner - Starting"
    echo "============================================================================"
    log_info "Video segment combiner starting"
    
    check_requirements
    validate_environment
    prepare_workspace
    download_manifest
    extract_segment_names
    download_segments
    create_concat_list
    concatenate_segments
    upload_output
    
    local total_elapsed=$(($(date +%s) - START_TIME))
    log_info "Video segment combiner complete total_elapsed=${total_elapsed}s"
    
    echo "============================================================================"
    echo "Video Segment Combiner - Complete"
    echo "============================================================================"
}

trap cleanup EXIT

main "$@"