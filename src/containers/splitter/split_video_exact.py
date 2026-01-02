#!/usr/bin/env python3
"""
split_video_exact.py

Accurately split a video into fixed-duration chunks by re-encoding and forcing keyframes
at exact boundaries, then using the ffmpeg segment muxer.

Why this is accurate:
- Segment muxer can only cut on keyframes.
- We force keyframes at t = N * chunk_seconds, so cuts land exactly on boundaries.

Usage:
  python3 split_video_exact.py "input.mp4" --minutes 5 --outdir segments_in
  python3 split_video_exact.py "input.mp4" --seconds 300 --outdir segments_in

Optional (faster on NVIDIA GPUs if available in your environment):
  python3 split_video_exact.py "input.mp4" --minutes 5 --vcodec h264_nvenc --outdir segments_in
"""

import argparse
import json
import logging
import math
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

# Configure logging with structured format for CloudWatch
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%SZ',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Configuration constants
DEFAULT_CHUNK_MINUTES: float = 5.0
DEFAULT_CRF: int = 18
DEFAULT_PRESET: str = "medium"
DEFAULT_PIX_FMT: str = "yuv420p"
DEFAULT_AUDIO_CODEC: str = "aac"
DEFAULT_AUDIO_BITRATE: str = "192k"
DEFAULT_VIDEO_CODEC: str = "libx264"
SEGMENT_TIME_DELTA: float = 0.05  # 50ms tolerance for segment boundaries
VIDEO_TRACK_TIMESCALE: int = 90000  # Standard MPEG timescale
ASSUMED_FPS: int = 30  # Fallback FPS for GOP calculation
FFMPEG_TIMEOUT_SECONDS: int = 7200  # 2 hour timeout for FFmpeg operations
SEGMENT_PATTERN: str = "seg_%04d.mp4"


def run_command(
    cmd: list[str],
    timeout: Optional[int] = None,
    capture_output: bool = True
) -> subprocess.CompletedProcess:
    """
    Run a command with optional timeout and error handling.

    Args:
        cmd: Command and arguments to run
        timeout: Timeout in seconds (None for no timeout)
        capture_output: Whether to capture stdout/stderr

    Returns:
        CompletedProcess object with return code and output

    Raises:
        subprocess.TimeoutExpired: If command times out
    """
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE if capture_output else None,
            stderr=subprocess.PIPE if capture_output else None,
            text=True,
            timeout=timeout
        )
        return result
    except subprocess.TimeoutExpired as e:
        logger.error(f"Command timed out after {timeout}s: {' '.join(cmd[:3])}...")
        raise


def validate_input_file(path: str) -> None:
    """
    Validate that the input file exists and is readable.

    Args:
        path: Path to the input video file

    Raises:
        SystemExit: If file is invalid
    """
    if not path:
        logger.error("Input file path is empty")
        sys.exit(1)

    file_path = Path(path)
    if not file_path.exists():
        logger.error(f"Input file does not exist: {path}")
        sys.exit(1)

    if not file_path.is_file():
        logger.error(f"Input path is not a file: {path}")
        sys.exit(1)

    if not os.access(path, os.R_OK):
        logger.error(f"Input file is not readable: {path}")
        sys.exit(1)

    # Check file size is non-zero
    if file_path.stat().st_size == 0:
        logger.error(f"Input file is empty: {path}")
        sys.exit(1)


def validate_output_dir(path: str) -> Path:
    """
    Validate and create output directory.

    Args:
        path: Path to the output directory

    Returns:
        Path object for the output directory

    Raises:
        SystemExit: If directory cannot be created
    """
    outdir = Path(path)
    try:
        outdir.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        logger.error(f"Permission denied creating output directory: {path}")
        sys.exit(1)
    except OSError as e:
        logger.error(f"Failed to create output directory: {path} - {e}")
        sys.exit(1)

    return outdir


def ffprobe_duration(path: str) -> float:
    """
    Get video duration using ffprobe.

    Args:
        path: Path to the video file

    Returns:
        Duration in seconds

    Raises:
        RuntimeError: If ffprobe fails
    """
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "json",
        path
    ]

    result = run_command(cmd, timeout=60)

    if result.returncode != 0:
        logger.error(f"ffprobe failed with exit code {result.returncode}")
        logger.error(f"stderr: {result.stderr}")
        raise RuntimeError(f"ffprobe failed:\n{result.stderr}")

    try:
        data = json.loads(result.stdout)
        duration = float(data["format"]["duration"])
        if duration <= 0:
            raise ValueError("Duration must be positive")
        return duration
    except (json.JSONDecodeError, KeyError, ValueError) as e:
        logger.error(f"Failed to parse ffprobe output: {e}")
        raise RuntimeError(f"Failed to parse video duration: {e}")


def build_stream_copy_command(
    input_path: str,
    output_dir: Path,
    chunk_seconds: float
) -> list[str]:
    """
    Build FFmpeg command for stream copy mode (fast, no re-encoding).

    Args:
        input_path: Path to input video
        output_dir: Output directory for segments
        chunk_seconds: Duration of each segment

    Returns:
        FFmpeg command as list of strings
    """
    return [
        "ffmpeg", "-hide_banner", "-y",
        "-i", input_path,
        "-c", "copy",
        "-f", "segment",
        "-segment_time", f"{chunk_seconds}",
        "-reset_timestamps", "1",
        "-map", "0",
        str(output_dir / SEGMENT_PATTERN)
    ]


def build_reencode_command(
    input_path: str,
    output_dir: Path,
    chunk_seconds: float,
    vcodec: str,
    acodec: str,
    abitrate: str,
    crf: int,
    preset: str,
    pix_fmt: str,
    force_keyframes: bool
) -> list[str]:
    """
    Build FFmpeg command for re-encoding mode (precise segment boundaries).

    Args:
        input_path: Path to input video
        output_dir: Output directory for segments
        chunk_seconds: Duration of each segment
        vcodec: Video codec to use
        acodec: Audio codec to use
        abitrate: Audio bitrate
        crf: Constant rate factor for quality
        preset: Encoder preset
        pix_fmt: Pixel format
        force_keyframes: Whether to force keyframes at boundaries

    Returns:
        FFmpeg command as list of strings
    """
    cmd = [
        "ffmpeg", "-hide_banner", "-y",
        "-i", input_path,
        "-map", "0",
        "-c:v", vcodec,
    ]

    # CRF only applies to x264/x265-style encoders
    if vcodec in ("libx264", "libx265"):
        cmd += ["-crf", str(crf), "-preset", preset]
    else:
        cmd += ["-preset", preset]

    cmd += ["-pix_fmt", pix_fmt]
    cmd += ["-c:a", acodec, "-b:a", abitrate]

    # Force keyframes at exact boundaries
    if force_keyframes:
        force_kf_expr = f"expr:gte(t,n_forced*{chunk_seconds})"
        cmd += ["-force_key_frames", force_kf_expr]

    # Set GOP size to match segment duration
    gop_size = int(chunk_seconds * ASSUMED_FPS)
    cmd += ["-g", str(gop_size)]
    cmd += ["-keyint_min", str(gop_size)]

    # Segment muxer with improved timing precision
    cmd += [
        "-f", "segment",
        "-segment_time", f"{chunk_seconds}",
        "-segment_time_delta", str(SEGMENT_TIME_DELTA),
        "-reset_timestamps", "1",
        "-movflags", "+faststart",
        "-video_track_timescale", str(VIDEO_TRACK_TIMESCALE),
        str(output_dir / SEGMENT_PATTERN)
    ]

    return cmd


def run_ffmpeg(cmd: list[str], timeout: int = FFMPEG_TIMEOUT_SECONDS) -> None:
    """
    Execute FFmpeg command with timeout and error handling.

    Args:
        cmd: FFmpeg command to run
        timeout: Timeout in seconds

    Raises:
        RuntimeError: If FFmpeg fails
        SystemExit: If FFmpeg times out
    """
    logger.info(f"Running FFmpeg with {timeout}s timeout...")
    logger.debug(f"Command: {' '.join(cmd)}")

    try:
        result = run_command(cmd, timeout=timeout)
    except subprocess.TimeoutExpired:
        logger.error(f"FFmpeg timed out after {timeout} seconds")
        logger.error("This may indicate a corrupted video or an extremely long file")
        sys.exit(1)

    if result.returncode != 0:
        logger.error("FFmpeg command failed")
        logger.error(f"Command: {' '.join(cmd)}")
        logger.error(f"STDERR:\n{result.stderr}")
        raise RuntimeError(f"ffmpeg failed with exit code {result.returncode}")


def main() -> None:
    """Main entry point for video splitting."""
    ap = argparse.ArgumentParser(
        description="Split video into fixed-duration segments"
    )
    ap.add_argument("input", help="Input video file")

    duration_group = ap.add_mutually_exclusive_group()
    duration_group.add_argument(
        "--minutes", type=float, default=DEFAULT_CHUNK_MINUTES,
        help=f"Chunk length in minutes (default {DEFAULT_CHUNK_MINUTES})"
    )
    duration_group.add_argument(
        "--seconds", type=float,
        help="Chunk length in seconds (overrides --minutes)"
    )

    ap.add_argument(
        "--outdir", default="segments_in",
        help="Output directory (default: segments_in)"
    )
    ap.add_argument(
        "--timeout", type=int, default=FFMPEG_TIMEOUT_SECONDS,
        help=f"FFmpeg timeout in seconds (default: {FFMPEG_TIMEOUT_SECONDS})"
    )

    # Re-encode controls
    ap.add_argument(
        "--vcodec", default=DEFAULT_VIDEO_CODEC,
        help=f"Video codec (default {DEFAULT_VIDEO_CODEC})"
    )
    ap.add_argument(
        "--crf", type=int, default=DEFAULT_CRF,
        help=f"CRF for x264/x265 (default {DEFAULT_CRF})"
    )
    ap.add_argument(
        "--preset", default=DEFAULT_PRESET,
        help=f"Encoder preset (default {DEFAULT_PRESET})"
    )
    ap.add_argument(
        "--pix-fmt", default=DEFAULT_PIX_FMT,
        help=f"Pixel format (default {DEFAULT_PIX_FMT})"
    )
    ap.add_argument(
        "--acodec", default=DEFAULT_AUDIO_CODEC,
        help=f"Audio codec (default {DEFAULT_AUDIO_CODEC})"
    )
    ap.add_argument(
        "--abitrate", default=DEFAULT_AUDIO_BITRATE,
        help=f"Audio bitrate (default {DEFAULT_AUDIO_BITRATE})"
    )

    ap.add_argument(
        "--force-keyframes", action="store_true", default=True,
        help="Force keyframes at exact boundaries (default ON)"
    )
    ap.add_argument(
        "--no-force-keyframes", dest="force_keyframes", action="store_false",
        help="Disable forcing keyframes (NOT recommended)"
    )
    ap.add_argument(
        "--stream-copy", action="store_true",
        help="Use stream copy (fast but less precise)"
    )

    args = ap.parse_args()

    # Validate inputs
    validate_input_file(args.input)
    outdir = validate_output_dir(args.outdir)

    # Calculate chunk duration
    chunk_s = args.seconds if args.seconds is not None else args.minutes * 60.0
    if chunk_s <= 0:
        logger.error("Chunk duration must be greater than 0")
        sys.exit(1)

    # Get video duration
    try:
        duration = ffprobe_duration(args.input)
    except RuntimeError as e:
        logger.error(f"Failed to get video duration: {e}")
        sys.exit(1)

    est_segments = int(math.ceil(duration / chunk_s))

    logger.info(f"Input: {args.input}")
    logger.info(f"Duration: {duration:.3f}s")
    logger.info(f"Chunk size: {chunk_s:.3f}s")
    logger.info(f"Estimated segments: {est_segments}")
    logger.info(f"Output dir: {outdir}")

    # Build and run FFmpeg command
    if args.stream_copy:
        logger.info("Using stream copy mode (fast, splits on existing keyframes)")
        cmd = build_stream_copy_command(args.input, outdir, chunk_s)
    else:
        logger.info("Using re-encode mode (precise segment boundaries)")
        cmd = build_reencode_command(
            args.input, outdir, chunk_s,
            args.vcodec, args.acodec, args.abitrate,
            args.crf, args.preset, args.pix_fmt,
            args.force_keyframes
        )

    try:
        run_ffmpeg(cmd, timeout=args.timeout)
    except RuntimeError:
        sys.exit(1)

    # Count generated segments
    segments = list(outdir.glob("seg_*.mp4"))
    logger.info(f"✅ Done splitting. Generated {len(segments)} segments")
    logger.info(f"Segments written to: {outdir}")


if __name__ == "__main__":
    main()
