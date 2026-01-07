# Submit RunPod Job Lambda

Lambda function that submits video upscaling jobs to RunPod with webhook callbacks and stores callback mappings in DynamoDB.

## Purpose

This Lambda is called by Step Functions to initiate RunPod jobs and set up webhook callbacks for resuming execution when jobs complete.

## Architecture

```
Step Functions → Lambda (submit_runpod_job) → RunPod API
                       ↓
                   DynamoDB (store callback mapping)
                       ↓
                   (Later: RunPod → Webhook → Resume Step Functions)
```

## Workflow

1. **Generate Callback Token**: Create secure random 64-character token
2. **Build Webhook URL**: `https://api-gateway-url/webhook/{callback_token}`
3. **Generate Presigned URLs**: Call existing `presign_s3_urls` Lambda for input/output
4. **Submit to RunPod**: POST job with webhook URL
5. **Store Mapping**: Save callback_token → task_token mapping in DynamoDB
6. **Return**: Quick response with callback_token and job_id

## Input Format

Expected from Step Functions:

```json
{
  "task_token": "$$.Task.Token",
  "exec_id": "execution-123",
  "segment": {
    "filename": "seg_0001.mp4",
    "input_key": "runs/exec-123/raw/seg_0001.mp4",
    "output_key": "runs/exec-123/upscaled/seg_0001.mp4"
  },
  "params": {
    "model": "7b",
    "resolution": 1080,
    "batch_size_strategy": "quality",
    "batch_size_quality": 129,
    "chunk_size_strategy": "recommended",
    "chunk_size_recommended": 64,
    "compile_dit": true,
    "compile_vae": true,
    "video_backend": "ffmpeg",
    "ten_bit": false
  },
  "bucket": "my-bucket",
  "presign_expires_secs": 21600
}
```

## Output Format

Returns to Step Functions:

```json
{
  "callback_token": "a1b2c3...64-char-hex",
  "job_id": "runpod-job-abc123",
  "webhook_url": "https://api-gateway.../webhook/a1b2c3...",
  "segment_filename": "seg_0001.mp4",
  "exec_id": "execution-123"
}
```

## DynamoDB Record Created

```json
{
  "callback_token": "a1b2c3...",
  "task_token": "AAAA...step-functions-token...",
  "job_id": "runpod-job-abc123",
  "exec_id": "execution-123",
  "segment_filename": "seg_0001.mp4",
  "status": "PENDING",
  "created_at": "2026-01-06T12:00:00Z",
  "expires_at": "2026-01-13T12:00:00Z",
  "ttl": 1736769600
}
```

## Environment Variables

**Required**:

- `CALLBACK_TABLE_NAME` - DynamoDB table for callback mappings
- `PRESIGN_LAMBDA_ARN` - ARN of presign_s3_urls Lambda
- `WEBHOOK_BASE_URL` - Base URL for webhooks (e.g., `https://api.../webhook/`)
- `RUNPOD_API_KEY` - RunPod API key for authentication
- `RUNPOD_ENDPOINT_URL` - RunPod endpoint URL (e.g., `https://api.runpod.ai/v2/{endpoint-id}/run`)

**Optional**:

- `BUCKET_NAME` - Default S3 bucket (can be overridden in event)
- `LOG_LEVEL` - Logging level (default: INFO)

## IAM Permissions

Lambda requires:

**DynamoDB**:

- `dynamodb:PutItem` - Store callback mappings

**Lambda**:

- `lambda:InvokeFunction` - Call presign_s3_urls Lambda

**Secrets Manager** (if API key stored there):

- `secretsmanager:GetSecretValue` - Retrieve RunPod API key

## RunPod Payload

Submits to RunPod with:

```json
{
  "input": {
    "input_presigned_url": "https://s3.../input?...",
    "output_presigned_url": "https://s3.../output?...",
    "params": {
      "model": "7b",
      "resolution": 1080,
      ...
    }
  },
  "webhook": "https://api-gateway.../webhook/a1b2c3..."
}
```

## Error Handling

- **Validation Errors**: Raises `ValueError` for missing/invalid inputs
- **Presign Failures**: Propagates errors from presign Lambda
- **RunPod Failures**: Raises `RuntimeError` with response details
- **DynamoDB Failures**: Propagates `ClientError`

All errors are logged with context and re-raised for Step Functions error handling.

## Testing

```bash
# Test locally (requires AWS credentials and environment variables)
python3 -c "
import json
from index import lambda_handler

event = {
    'task_token': 'test-token',
    'exec_id': 'test-exec',
    'segment': {
        'filename': 'seg_0001.mp4',
        'input_key': 'runs/test/raw/seg_0001.mp4',
        'output_key': 'runs/test/upscaled/seg_0001.mp4'
    },
    'params': {'model': '7b', 'resolution': 1080},
    'bucket': 'my-test-bucket',
    'presign_expires_secs': 3600
}

result = lambda_handler(event, None)
print(json.dumps(result, indent=2))
"
```

## Monitoring

**CloudWatch Metrics**:

- Lambda invocation count
- Lambda error count
- Lambda duration
- DynamoDB write throttles

**CloudWatch Logs**:

- Callback token generation
- Presigned URL generation
- RunPod submission
- DynamoDB storage
- Error traces

**Key Log Messages**:

- `Generated callback token: {token}`
- `Webhook URL: {url}`
- `Presigned URLs generated successfully`
- `RunPod job submitted successfully: {job_id}`
- `Callback mapping stored successfully`
- `Error submitting to RunPod: {error}`

## Security

- **Callback Tokens**: 256-bit random tokens (cryptographically secure)
- **API Keys**: Stored in environment variables (should use Secrets Manager in production)
- **Presigned URLs**: Time-limited, scoped to specific operations
- **Task Tokens**: Never exposed to RunPod, only stored in DynamoDB

## Performance

- **Cold Start**: ~2-3 seconds (includes boto3 initialization)
- **Warm Execution**: ~500ms-1s (presign + RunPod API call)
- **Timeout**: Recommend 30 seconds
- **Memory**: Recommend 256 MB

## DynamoDB TTL

Records automatically expire after 7 days using the `ttl` attribute. This ensures cleanup of old callback mappings.
