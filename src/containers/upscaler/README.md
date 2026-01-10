# Video Upscaler Container (ECS Batch)

This container performs video segment upscaling using SeedVR2 on AWS ECS with GPU support.

## Overview

The upscaler container is designed to run as part of an AWS Step Functions workflow, processing individual video segments with AI-powered upscaling. It supports both ECS Batch execution (with direct S3 access via IAM roles) and can be configured with various SeedVR2 parameters for optimal quality and performance.

## Architecture

- **Base Image**: `nvidia/cuda:12.1.0-runtime-ubuntu22.04`
- **GPU Support**: CUDA 12.1 with PyTorch
- **Execution Mode**: AWS Batch (EC2 with GPU)
- **Storage**: Direct S3 access via IAM roles

## Features

- ✅ GPU-accelerated video upscaling with SeedVR2
- ✅ Automatic model caching across job executions
- ✅ Direct S3 integration for input/output
- ✅ Comprehensive logging and metrics
- ✅ Configurable batch sizes and chunk strategies
- ✅ Support for various attention modes (including SageAttention)
- ✅ Health checks for GPU availability

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `INPUT_SEGMENT_S3_URI` | S3 URI of the input video segment | `s3://bucket/runs/123/raw/seg_0001.mp4` |
| `OUTPUT_SEGMENT_S3_URI` | S3 URI for the upscaled output | `s3://bucket/runs/123/upscaled/seg_0001.mp4` |
| `EXEC_ID` | Execution identifier | `1704067200000` |
| `SEGMENT_INDEX` | Segment index number | `1` |

### SeedVR2 Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL` | `7b` | Model size (7b or 2b) |
| `RESOLUTION` | `1080` | Target resolution |
| `SEED` | `42` | Random seed for reproducibility |
| `COLOR_CORRECTION` | `lab` | Color correction mode |
| `DEBUG` | `false` | Enable debug output |

### Batch Size Strategy

| Variable | Default | Description |
|----------|---------|-------------|
| `BATCH_SIZE_STRATEGY` | `explicit` | Strategy: `explicit`, `conservative`, or `quality` |
| `BATCH_SIZE_EXPLICIT` | `129` | Explicit batch size value |
| `BATCH_SIZE_CONSERVATIVE` | - | Conservative batch size (from recommendations) |
| `BATCH_SIZE_QUALITY` | - | Quality-optimized batch size (from recommendations) |

### Chunk Size Strategy

| Variable | Default | Description |
|----------|---------|-------------|
| `CHUNK_SIZE_STRATEGY` | `explicit` | Strategy: `explicit`, `recommended`, or `fallback` |
| `CHUNK_SIZE_EXPLICIT` | `null` | Explicit chunk size value |
| `CHUNK_SIZE_RECOMMENDED` | - | Recommended chunk size (from recommendations) |
| `CHUNK_SIZE_FALLBACK` | - | Fallback chunk size (from recommendations) |

### Optional Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `ATTENTION_MODE` | - | Attention mode (e.g., `sageattn_2`, `sageattn_3`) |
| `TEMPORAL_OVERLAP` | - | Temporal overlap for processing |
| `VAE_ENCODE_TILED` | `false` | Use tiled VAE encoding |
| `VAE_DECODE_TILED` | `false` | Use tiled VAE decoding |
| `CACHE_DIT` | `false` | Cache DIT model |
| `CACHE_VAE` | `false` | Cache VAE model |

## Model Caching

Models are automatically downloaded by SeedVR2 on first run and cached in `/models` directory. The directory is designed to be mounted as a persistent volume in production for efficient model reuse across job executions.

### Model Sources

- <https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler/blob/main/src/utils/model_registry.py>
- <https://huggingface.co/numz/SeedVR2_comfyUI/tree/main>

## Building the Image

```bash
cd src/containers/upscaler
docker build -t upscaler:latest .
```

### Build Arguments

- `SEEDVR2_REPO`: Git repository URL (default: ComfyUI-SeedVR2_VideoUpscaler)
- `SEEDVR2_REF`: Git ref to checkout (default: v2.5.23)

## Running Locally

```bash
docker run --gpus all \
  -e INPUT_SEGMENT_S3_URI=s3://bucket/input.mp4 \
  -e OUTPUT_SEGMENT_S3_URI=s3://bucket/output.mp4 \
  -e EXEC_ID=test123 \
  -e SEGMENT_INDEX=1 \
  -v ~/.aws:/root/.aws:ro \
  upscaler:latest
```

## AWS ECS Configuration

### Instance Requirements

- **GPU Required**: 1 NVIDIA GPU (T4, A10G, or similar)
- **Recommended Instances**:
  - `g4dn.xlarge` (1 GPU, 4 vCPUs, 16 GB RAM) - Cost effective
  - `g4dn.2xlarge` (1 GPU, 8 vCPUs, 32 GB RAM) - Better performance
  - `g5.xlarge` (1 GPU, 4 vCPUs, 16 GB RAM) - Newer generation

### Quota Considerations

With your current quotas:

- **On-Demand G/VT**: 32 vCPUs → Up to 8x `g4dn.xlarge` or 4x `g4dn.2xlarge`
- **Spot G/VT**: 8 vCPUs → Up to 2x `g4dn.xlarge` (significant cost savings)

**Recommendation**: Use Spot instances where possible for 70% cost savings. The Terraform configuration already prioritizes Spot instances.

### ECS Task Definition

The container is configured via the Terraform Batch module at `src/terraform/modules/batch/upscale/`. Key settings:

- **Platform**: EC2 (GPU required)
- **vCPUs**: 4 (configurable)
- **Memory**: 16384 MB (configurable)
- **GPU Count**: 1
- **Max Concurrency**: 4 (default, configurable)

## Execution in Step Functions

The Step Functions workflow ([upscale_video.tftpl](../../terraform/modules/step_functions/definitions/upscale_video.tftpl)) supports two execution modes:

### ECS Mode (GPU-based)

Set `execution_mode: "ecs"` in the workflow input:

```json
{
  "input_s3_uri": "s3://bucket/input.mp4",
  "execution_mode": "ecs",
  "split_job_definition": "arn:aws:batch:...",
  "upscale_job_definition": "arn:aws:batch:...",
  "combine_job_definition": "arn:aws:batch:...",
  "params": {
    "model": "7b",
    "resolution": 1080,
    "batch_size_strategy": "explicit",
    "batch_size_explicit": 129
  }
}
```

### RunPod Mode (Alternative)

Set `execution_mode: "runpod"` to use the RunPod execution path instead.

## Monitoring & Logging

### CloudWatch Logs

Logs are sent to: `/aws/batch/{project_name}-upscale-{environment}`

### Metrics Logged

- `model_cache_hit`: Whether models were cached
- `model_file_count`: Number of model files found
- `download_duration_seconds`: Time to download input
- `input_segment_size_bytes`: Input file size
- `upscale_duration_seconds`: Time for upscaling
- `output_segment_size_bytes`: Output file size
- `upload_duration_seconds`: Time to upload output
- `job_status`: Final job status

## Troubleshooting

### GPU Not Available

- **Error**: `RuntimeError: CUDA not available`
- **Solution**: Ensure GPU instances are requested and available in your region

### Out of Memory

- **Error**: `CUDA out of memory`
- **Solution**:
  - Reduce `BATCH_SIZE_EXPLICIT`
  - Enable `VAE_ENCODE_TILED` and `VAE_DECODE_TILED`
  - Use smaller model (`2b` instead of `7b`)
  - Switch to larger instance type

### Model Download Failures

- **Error**: Model download errors
- **Solution**:
  - Check internet connectivity from ECS instances
  - Verify HuggingFace is accessible
  - Models auto-download on first run; may take 5-10 minutes

### S3 Access Denied

- **Error**: `AccessDenied` when accessing S3
- **Solution**: Verify IAM role attached to Batch job has S3 read/write permissions

## Performance Tuning

### For Speed

```json
{
  "batch_size_strategy": "explicit",
  "batch_size_explicit": 129,
  "attention_mode": "sageattn_3",
  "chunk_size_strategy": "recommended"
}
```

### For Quality

```json
{
  "batch_size_strategy": "quality",
  "vae_encode_tiled": true,
  "vae_decode_tiled": true,
  "temporal_overlap": 4
}
```

### For Memory Efficiency

```json
{
  "batch_size_strategy": "conservative",
  "vae_encode_tiled": true,
  "vae_decode_tiled": true,
  "cache_dit": false,
  "cache_vae": false
}
```

## Security

- ✅ Runs in isolated VPC
- ✅ IAM role-based S3 access (no credentials in container)
- ✅ Server-side encryption (AES256) for S3 uploads
- ✅ No hardcoded secrets
- ✅ Health checks for GPU availability

## Development

### Testing Changes

1. Build the image locally
2. Push to ECR
3. Update Terraform job definition with new image tag
4. Test with a single segment via Step Functions

### Adding New Parameters

1. Add environment variable to [upscale.sh](upscale.sh)
2. Update [upscale_video.tftpl](../../terraform/modules/step_functions/definitions/upscale_video.tftpl) with new parameter
3. Document in this README

## License

See project LICENSE file.
