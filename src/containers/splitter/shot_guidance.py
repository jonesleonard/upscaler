#!/usr/bin/env python3
"""
shot_guidance.py

Usage:
  python3 shot_guidance.py "input.mp4"
  python3 shot_guidance.py "input.mp4" --scene-threshold 0.30
  python3 shot_guidance.py "input.mp4" --fps 29.97
  python3 shot_guidance.py "input.mp4" --print-skips
  python3 shot_guidance.py "input.mp4" --json  # For pipeline integration

What it does:
  - Uses ffmpeg scene detection to estimate cut timestamps
  - Uses ffprobe to get duration and (if available) frame count
  - Computes shot length stats (avg, median, p75, p90)
  - Prints SeedVR2 tuning guidance:
      * batch_size candidates (4n+1 format required by SeedVR2)
      * a recommended chunk_size based on a heuristic tied to shot structure
      * a conservative fallback chunk_size (1500)
      * optional skip_first_frames list
"""

import argparse
import json
import logging
import math
import os
import re
import subprocess
import sys
from statistics import median
from typing import Any, Dict, List, Optional, Tuple

# Configure logging with structured format for CloudWatch
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%SZ',
    stream=sys.stderr  # Log to stderr so JSON output goes to stdout cleanly
)
logger = logging.getLogger(__name__)

# Configuration constants
DEFAULT_SCENE_THRESHOLD: float = 0.30
DEFAULT_FPS: float = 30.0
DEFAULT_MAX_SKIPS: int = 200
BATCH_CAP: int = 257  # 4*64+1, reasonable upper limit
FFMPEG_TIMEOUT_SECONDS: int = 3600  # 1 hour timeout for analysis
FFPROBE_TIMEOUT_SECONDS: int = 60

# Regex for parsing pts_time from ffmpeg output
PTS_RE = re.compile(r"pts_time:([0-9.]+)")


def run_command(
    cmd: List[str],
    timeout: Optional[int] = None
) -> subprocess.CompletedProcess:
    """
    Run a command with optional timeout.

    Args:
        cmd: Command and arguments to run
        timeout: Timeout in seconds (None for no timeout)

    Returns:
        CompletedProcess object

    Raises:
        subprocess.TimeoutExpired: If command times out
    """
    try:
        return subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out after {timeout}s: {' '.join(cmd[:3])}...")
        raise


def validate_input_file(path: str) -> None:
    """
    Validate that the input file exists and is readable.

    Args:
        path: Path to the input video file

    Raises:
        ValueError: If file is invalid
    """
    if not path:
        raise ValueError("Input file path is empty")

    if not os.path.exists(path):
        raise ValueError(f"Input file does not exist: {path}")

    if not os.path.isfile(path):
        raise ValueError(f"Input path is not a file: {path}")

    if not os.access(path, os.R_OK):
        raise ValueError(f"Input file is not readable: {path}")


def ffprobe_json(path: str) -> Dict[str, Any]:
    """
    Get video metadata using ffprobe.

    Args:
        path: Path to the video file

    Returns:
        Parsed JSON output from ffprobe

    Raises:
        RuntimeError: If ffprobe fails
    """
    cmd = [
        "ffprobe", "-v", "error",
        "-of", "json",
        "-show_format",
        "-show_streams",
        path
    ]

    result = run_command(cmd, timeout=FFPROBE_TIMEOUT_SECONDS)

    if result.returncode != 0:
        raise RuntimeError(f"ffprobe failed:\n{result.stderr}")

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse ffprobe output: {e}")


def parse_rate(rate_str: str) -> float:
    """
    Parse frame rate string (e.g., "30000/1001") to float.

    Args:
        rate_str: Frame rate string from ffprobe

    Returns:
        Frame rate as float, or NaN if invalid
    """
    if not rate_str or rate_str == "0/0":
        return float("nan")
    if "/" in rate_str:
        parts = rate_str.split("/", 1)
        try:
            n = float(parts[0])
            d = float(parts[1])
            return n / d if d else float("nan")
        except ValueError:
            return float("nan")
    try:
        return float(rate_str)
    except ValueError:
        return float("nan")


def get_duration_frames_fps(
    path: str
) -> Tuple[float, Optional[int], float, float]:
    """
    Get video duration, frame count, and FPS.

    Args:
        path: Path to the video file

    Returns:
        Tuple of (duration, nb_frames, avg_fps, r_fps)
    """
    data = ffprobe_json(path)
    fmt = data.get("format", {})
    streams = data.get("streams", [])

    duration = float(fmt.get("duration", "nan"))

    v0 = next((s for s in streams if s.get("codec_type") == "video"), {})

    nb_frames_str = v0.get("nb_frames")
    try:
        nb_frames = int(nb_frames_str) if nb_frames_str is not None else None
    except ValueError:
        nb_frames = None

    avg_fps = parse_rate(v0.get("avg_frame_rate", ""))
    r_fps = parse_rate(v0.get("r_frame_rate", ""))

    return duration, nb_frames, avg_fps, r_fps


def get_effective_fps(
    duration: float,
    nb_frames: Optional[int],
    avg_fps: float,
    r_fps: float,
    override: Optional[float]
) -> float:
    """
    Determine effective FPS from available sources.

    Args:
        duration: Video duration in seconds
        nb_frames: Number of frames (if available)
        avg_fps: Average FPS from ffprobe
        r_fps: Real FPS from ffprobe
        override: User-specified FPS override

    Returns:
        Effective FPS to use
    """
    if override is not None and override > 0:
        return override
    # Best-effort for variable frame rate: frames/duration if available
    if nb_frames is not None and duration and not math.isnan(duration) and duration > 0:
        return nb_frames / duration
    if not math.isnan(avg_fps) and avg_fps > 0:
        return avg_fps
    if not math.isnan(r_fps) and r_fps > 0:
        return r_fps
    return DEFAULT_FPS


def get_cut_times(path: str, thresh: float) -> List[float]:
    """
    Detect scene cuts using ffmpeg.

    Args:
        path: Path to the video file
        thresh: Scene detection threshold

    Returns:
        List of cut timestamps in seconds
    """
    cmd = [
        "ffmpeg", "-hide_banner", "-i", path,
        "-vf", f"select='gt(scene,{thresh})',showinfo",
        "-an", "-f", "null", "-"
    ]

    try:
        result = run_command(cmd, timeout=FFMPEG_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        logger.warning("Scene detection timed out, returning empty cut list")
        return []

    cuts = [float(m.group(1)) for m in PTS_RE.finditer(result.stderr)]
    return sorted(set(cuts))


def percentile(values: List[float], p: float) -> float:
    """
    Calculate linear-interpolated percentile.

    Args:
        values: List of values
        p: Percentile in [0, 100]

    Returns:
        Percentile value
    """
    if not values:
        return float("nan")
    v = sorted(values)
    if len(v) == 1:
        return v[0]
    k = (len(v) - 1) * (p / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return v[int(k)]
    return v[f] * (c - k) + v[c] * (k - f)


def round_to(x: float, base: int) -> int:
    """Round to nearest multiple of base."""
    return int(base * round(x / base))


def round_to_4n_plus_1(x: float) -> int:
    """
    Round to nearest valid SeedVR2 batch_size (4n+1 format: 1, 5, 9, 13...).

    Args:
        x: Value to round

    Returns:
        Nearest 4n+1 value
    """
    n = round((x - 1) / 4.0)
    return max(1, int(4 * n + 1))


def clamp_int(x: int, lo: int, hi: int) -> int:
    """Clamp integer to range [lo, hi]."""
    return max(lo, min(hi, x))


def recommend_batch_sizes(
    median_s: float,
    shots_per_min: float,
    p75_frames: float
) -> Tuple[str, List[int], int, int]:
    """
    Calculate batch_size recommendations based on shot statistics.
    All recommendations follow SeedVR2's 4n+1 constraint (1, 5, 9, 13, 17, 21, 25...).

    Args:
        median_s: Median shot length in seconds
        shots_per_min: Shots per minute
        p75_frames: 75th percentile shot length in frames

    Returns:
        Tuple of (pace_label, candidates, conservative, quality)
    """
    if median_s < 5 or (not math.isnan(shots_per_min) and shots_per_min > 12):
        pace = "very fast-cut"
        candidates = [49, 65, 97]
    elif median_s < 12 or (not math.isnan(shots_per_min) and shots_per_min > 7):
        pace = "moderate cuts"
        candidates = [97, 129, 161]
    else:
        pace = "longer takes"
        candidates = [129, 193, 257]

    candidates = [c for c in candidates if c <= BATCH_CAP]

    # Stat-based anchors: p75_frames / divisor, rounded to 4n+1
    stat_conservative = clamp_int(round_to_4n_plus_1(p75_frames / 6.0), 49, BATCH_CAP)
    stat_quality = clamp_int(round_to_4n_plus_1(p75_frames / 4.0), 65, BATCH_CAP)

    return pace, candidates, stat_conservative, stat_quality


def recommend_chunk_size(p75_frames: float) -> Tuple[int, str, int]:
    """
    Calculate chunk size recommendations.

    Args:
        p75_frames: 75th percentile shot length in frames

    Returns:
        Tuple of (recommended, reason, fallback)
    """
    conservative_fallback = 1500

    if math.isnan(p75_frames) or p75_frames <= 0:
        return conservative_fallback, "fallback (could not compute p75_frames)", conservative_fallback

    recommended = clamp_int(round_to(2.0 * p75_frames, 300), 900, 3600)
    reason = "≈ 2×p75_frames (rounded to 300, clamped 900–3600)"
    return recommended, reason, conservative_fallback


def analyze_video(
    path: str,
    scene_threshold: float,
    fps_override: Optional[float]
) -> Dict[str, Any]:
    """
    Analyze video and generate shot guidance.

    Args:
        path: Path to the video file
        scene_threshold: Scene detection threshold
        fps_override: Optional FPS override

    Returns:
        Analysis results dictionary
    """
    validate_input_file(path)

    duration, nb_frames, avg_fps, r_fps = get_duration_frames_fps(path)
    fps = get_effective_fps(duration, nb_frames, avg_fps, r_fps, fps_override)

    cuts = get_cut_times(path, scene_threshold)

    # Shot boundaries
    times = [0.0] + cuts + [duration]
    shot_lengths = [
        times[i + 1] - times[i]
        for i in range(len(times) - 1)
        if times[i + 1] > times[i]
    ]

    if not shot_lengths:
        return {
            "error": "Could not compute shot lengths (no cuts found or invalid duration)",
            "duration": duration,
            "fps": fps
        }

    avg_s = sum(shot_lengths) / len(shot_lengths)
    med_s = median(shot_lengths)
    p75_s = percentile(shot_lengths, 75)
    p90_s = percentile(shot_lengths, 90)

    med_f = med_s * fps
    p75_f = p75_s * fps
    p90_f = p90_s * fps

    shots = len(shot_lengths)
    shots_per_min = shots / (duration / 60.0) if duration > 0 else float("nan")

    # Recommendations
    pace, batch_candidates, stat_batch_cons, stat_batch_qual = recommend_batch_sizes(
        med_s, shots_per_min, p75_f
    )
    chunk_rec, chunk_reason, chunk_fallback = recommend_chunk_size(p75_f)

    # Estimate total frames
    total_frames = nb_frames if nb_frames is not None else int(round(duration * fps))

    return {
        "duration": duration,
        "fps": fps,
        "total_frames": total_frames,
        "scene_threshold": scene_threshold,
        "detected_cuts": len(cuts),
        "shots": shots,
        "shots_per_minute": shots_per_min if not math.isnan(shots_per_min) else None,
        "shot_stats": {
            "average_seconds": avg_s,
            "median_seconds": med_s,
            "p75_seconds": p75_s,
            "p90_seconds": p90_s,
            "median_frames": med_f,
            "p75_frames": p75_f,
            "p90_frames": p90_f
        },
        "recommendations": {
            "editing_pace": pace,
            "batch_size_candidates": batch_candidates,
            "batch_size_conservative": stat_batch_cons,
            "batch_size_quality": stat_batch_qual,
            "chunk_size": chunk_rec,
            "chunk_size_fallback": chunk_fallback
        }
    }


def print_human_readable(result: Dict[str, Any], path: str, print_skips: bool, max_skips: int) -> None:
    """
    Print analysis results in human-readable format.

    Args:
        result: Analysis results
        path: Input file path
        print_skips: Whether to print skip values
        max_skips: Maximum skip values to print
    """
    if "error" in result:
        print(result["error"])
        return

    stats = result["shot_stats"]
    recs = result["recommendations"]

    print("=== Shot length stats ===")
    print(f"Input: {path}")
    print(f"Scene threshold: {result['scene_threshold']}")
    print(f"Duration: {result['duration']:.3f} s")
    print(f"FPS (effective): {result['fps']:.5f}")
    print(f"Total frames: {result['total_frames']}")
    print(f"Detected cuts: {result['detected_cuts']}")
    print(f"Shots: {result['shots']}")

    spm = result['shots_per_minute']
    print(f"Shots per minute: {spm:.2f}" if spm else "Shots per minute: n/a")

    print(f"Average shot length: {stats['average_seconds']:.3f} s")
    print(f"Median shot length:  {stats['median_seconds']:.3f} s")
    print(f"75th percentile:     {stats['p75_seconds']:.3f} s")
    print(f"90th percentile:     {stats['p90_seconds']:.3f} s")
    print(f"(Frames) median ≈ {stats['median_frames']:.1f}, p75 ≈ {stats['p75_frames']:.1f}, p90 ≈ {stats['p90_frames']:.1f}")

    print("\n=== SeedVR2 guidance (heuristics) ===")
    print(f"Editing pace guess: {recs['editing_pace']}")

    print("\nbatch_size suggestions:")
    print(f"  Start candidates: {', '.join(map(str, recs['batch_size_candidates']))}")
    print(f"  Stat-based (conservative): {recs['batch_size_conservative']}  (≈ p75_frames/6)")
    print(f"  Stat-based (quality bias): {recs['batch_size_quality']}  (≈ p75_frames/4)")

    print("\nchunking suggestions (Streaming Mode):")
    print(f"  Recommended chunk_size: {recs['chunk_size']}")
    print(f"  Conservative fallback:  {recs['chunk_size_fallback']}  (~50s at 30fps)")

    if print_skips:
        chunk_size = recs['chunk_size']
        total_frames = result['total_frames']
        print("\nskip_first_frames values:")
        skips = list(range(0, total_frames, chunk_size))
        if len(skips) > max_skips:
            skips = skips[:max_skips]
            truncated = True
        else:
            truncated = False

        line = []
        for s in skips:
            line.append(str(s))
            if len(line) >= 12:
                print("  " + ", ".join(line))
                line = []
        if line:
            print("  " + ", ".join(line))
        if truncated:
            print(f"  ... (truncated, increase --max-skips to print more)")


def main() -> None:
    """Main entry point for shot guidance analysis."""
    ap = argparse.ArgumentParser(
        description="Analyze video for shot guidance recommendations"
    )
    ap.add_argument("input", help="Input video file")
    ap.add_argument(
        "--scene-threshold", type=float, default=DEFAULT_SCENE_THRESHOLD,
        help=f"Scene threshold (default {DEFAULT_SCENE_THRESHOLD})"
    )
    ap.add_argument(
        "--fps", type=float, default=None,
        help="Override FPS (e.g., 29.97)"
    )
    ap.add_argument(
        "--print-skips", action="store_true",
        help="Print skip_first_frames list"
    )
    ap.add_argument(
        "--max-skips", type=int, default=DEFAULT_MAX_SKIPS,
        help=f"Max skip values to print (default {DEFAULT_MAX_SKIPS})"
    )
    ap.add_argument(
        "--json", action="store_true",
        help="Output as JSON for pipeline integration"
    )

    args = ap.parse_args()

    try:
        result = analyze_video(args.input, args.scene_threshold, args.fps)
    except ValueError as e:
        logger.error(str(e))
        if args.json:
            print(json.dumps({"error": str(e)}))
        sys.exit(1)
    except RuntimeError as e:
        logger.error(str(e))
        if args.json:
            print(json.dumps({"error": str(e)}))
        sys.exit(1)
    except subprocess.TimeoutExpired:
        error_msg = "Analysis timed out"
        logger.error(error_msg)
        if args.json:
            print(json.dumps({"error": error_msg}))
        sys.exit(1)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print_human_readable(result, args.input, args.print_skips, args.max_skips)


if __name__ == "__main__":
    main()
