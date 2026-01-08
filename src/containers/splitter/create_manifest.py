#!/usr/bin/env python3
"""
Create a manifest JSON file listing all video segments.

This script scans for seg_*.mp4 files in the output directory and
generates a manifest.json containing metadata about the segmentation
and shot guidance recommendations.
"""

import glob
import json
import logging
import os
import re
import sys
from typing import Any, Dict, List, Optional

# Configure logging with structured format for CloudWatch
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%SZ',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Configuration constants
DEFAULT_OUTPUT_DIR: str = "/work/out"
DEFAULT_CHUNK_SECONDS: float = 300.0
SEGMENT_PATTERN: str = "seg_*.mp4"
MANIFEST_FILENAME: str = "manifest.json"
S3_URI_PATTERN: re.Pattern = re.compile(r'^s3://[a-z0-9][a-z0-9.-]*[a-z0-9](/.*)?$')


def validate_s3_uri(uri: str, field_name: str) -> None:
    """
    Validate that a string is a valid S3 URI.

    Args:
        uri: The S3 URI to validate
        field_name: Name of the field for error messages

    Raises:
        ValueError: If the URI is invalid
    """
    if not uri:
        raise ValueError(f"{field_name} is required")

    if not uri.startswith("s3://"):
        raise ValueError(f"{field_name} must start with 's3://', got: {uri}")

    if not S3_URI_PATTERN.match(uri):
        raise ValueError(f"{field_name} is not a valid S3 URI: {uri}")


def validate_output_dir(path: str) -> None:
    """
    Validate that the output directory exists and is readable.

    Args:
        path: Path to the output directory

    Raises:
        ValueError: If directory is invalid
    """
    if not path:
        raise ValueError("Output directory path is required")

    if not os.path.exists(path):
        raise ValueError(f"Output directory does not exist: {path}")

    if not os.path.isdir(path):
        raise ValueError(f"Output path is not a directory: {path}")

    if not os.access(path, os.R_OK):
        raise ValueError(f"Output directory is not readable: {path}")


def validate_chunk_seconds(chunk_seconds: float) -> None:
    """
    Validate chunk duration.

    Args:
        chunk_seconds: Duration in seconds

    Raises:
        ValueError: If duration is invalid
    """
    if chunk_seconds <= 0:
        raise ValueError(f"Chunk seconds must be positive, got: {chunk_seconds}")

    if chunk_seconds > 86400:  # 24 hours
        raise ValueError(f"Chunk seconds exceeds maximum (86400): {chunk_seconds}")


def create_manifest(
    output_dir: str,
    chunk_seconds: Optional[float],
    s3_prefix: str,
    shot_guidance: Optional[Dict[str, Any]] = None,
    output_file: str = MANIFEST_FILENAME
) -> Dict[str, Any]:
    """
    Generate a manifest file listing all video segments.

    Parameters:
        output_dir: Directory containing the segment files
        chunk_seconds: Duration of each chunk in seconds (None if using segment count mode)
        s3_prefix: S3 prefix where segments are uploaded
        shot_guidance: Optional shot guidance metadata from shot_guidance.py
        output_file: Name of the manifest file to create

    Returns:
        The manifest dictionary that was written

    Raises:
        ValueError: If validation fails
        IOError: If file cannot be written
    """
    # Validate inputs
    validate_output_dir(output_dir)
    if chunk_seconds is not None:
        validate_chunk_seconds(chunk_seconds)
    validate_s3_uri(s3_prefix, "s3_prefix")

    # Find all segment files and sort them
    segment_pattern = os.path.join(output_dir, SEGMENT_PATTERN)
    segments = sorted(glob.glob(segment_pattern))

    if not segments:
        logger.warning(f"No segments found matching pattern: {segment_pattern}")

    # Normalize S3 prefix (remove trailing slash)
    s3_prefix_normalized = s3_prefix.rstrip('/')

    # Build manifest structure
    manifest: Dict[str, Any] = {
        "version": "1.0",
        "chunk_seconds": chunk_seconds,
        "segment_count": len(segments),
        "segments": [
            {
                "index": i,
                "filename": os.path.basename(path),
                "s3_uri": f"{s3_prefix_normalized}/raw/{os.path.basename(path)}"
            }
            for i, path in enumerate(segments)
        ]
    }

    # Add shot guidance metadata if available
    if shot_guidance:
        manifest["metadata"] = shot_guidance

    # Write manifest to file
    manifest_path = os.path.join(output_dir, output_file)
    try:
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
    except IOError as e:
        logger.error(f"Failed to write manifest file: {manifest_path}")
        raise

    logger.info(f"Created manifest with {len(segments)} segments: {manifest_path}")

    return manifest


def main() -> None:
    """Main entry point for manifest creation."""
    # Read configuration from environment variables
    out_dir = os.environ.get("OUTPUT_DIR", DEFAULT_OUTPUT_DIR)
    s3_output_prefix = os.environ.get("OUTPUT_S3_PREFIX", "")
    shot_guidance_json = os.environ.get("SHOT_GUIDANCE_JSON", "")

    # Parse chunk seconds or segment count with error handling
    segment_count_str = os.environ.get("SEGMENT_COUNT", "")
    chunk_seconds_str = os.environ.get("CHUNK_SECONDS", "")

    # If SEGMENT_COUNT is set, use None for chunk_sec (will be calculated later)
    # Otherwise use CHUNK_SECONDS or default
    if segment_count_str:
        chunk_sec = None  # Will be stored as null in manifest when using segment count
        try:
            segment_count = int(segment_count_str)
            if segment_count <= 0:
                raise ValueError("SEGMENT_COUNT must be positive")
        except ValueError:
            logger.error("SEGMENT_COUNT must be a valid positive integer")
            sys.exit(1)
    else:
        try:
            chunk_sec = float(chunk_seconds_str) if chunk_seconds_str else DEFAULT_CHUNK_SECONDS
        except ValueError:
            logger.error("CHUNK_SECONDS must be a valid number")
            sys.exit(1)

    # Validate required environment variables
    if not s3_output_prefix:
        logger.error("OUTPUT_S3_PREFIX environment variable is required")
        sys.exit(1)

    # Validate S3 URI format early
    try:
        validate_s3_uri(s3_output_prefix, "OUTPUT_S3_PREFIX")
    except ValueError as e:
        logger.error(str(e))
        sys.exit(1)

    # Parse shot guidance if provided
    shot_guidance: Optional[Dict[str, Any]] = None
    if shot_guidance_json:
        try:
            shot_guidance = json.loads(shot_guidance_json)
            logger.info("Parsed shot guidance metadata")
        except json.JSONDecodeError as e:
            logger.warning(f"Failed to parse SHOT_GUIDANCE_JSON: {e}")
            logger.warning("Manifest will be created without shot guidance metadata")

    # Create manifest
    try:
        create_manifest(out_dir, chunk_sec, s3_output_prefix, shot_guidance)
    except (ValueError, IOError) as e:
        logger.error(f"Failed to create manifest: {e}")
        sys.exit(1)

    logger.info("Manifest creation completed successfully")


if __name__ == "__main__":
    main()
