# RunPod Webhook Handler

Lambda function that receives webhook callbacks from RunPod and resumes Step Functions executions using the `waitForTaskToken` pattern.

## Architecture

```text
Step Functions → RunPod (with webhook URL) → API Gateway → Lambda → Step Functions (resume)
                                                    ↓
                                                DynamoDB (lookup task_token)
```

## DynamoDB Table Schema

**Table Name**: `{prefix}-runpod-callbacks`

**Primary Key**: `callback_token` (string)

**Attributes**:

- `callback_token` (string, PK) - Unique callback identifier
- `task_token` (string) - Step Functions task token for resuming execution
- `job_id` (string) - RunPod job ID
- `exec_id` (string) - Execution ID for tracing
- `segment_filename` (string) - Video segment filename
- `status` (string) - PENDING | COMPLETED | FAILED
- `created_at` (string) - ISO timestamp when record was created
- `completed_at` (string, optional) - ISO timestamp when job completed
- `result` (map, optional) - Job result metadata (output or error)

**TTL**: Records expire after 7 days using `ttl` attribute

## Webhook Flow

1. **Job Submission**: Step Functions creates DynamoDB record with callback_token and task_token
2. **Job Processing**: RunPod processes video segment
3. **Webhook Callback**: RunPod POSTs to `/webhook/{callback_token}` with status
4. **Lambda Processing**:
   - Looks up task_token from DynamoDB using callback_token
   - Checks if already completed (idempotent)
   - Calls `SendTaskSuccess` or `SendTaskFailure` to resume Step Functions
   - Updates DynamoDB record with completion status
5. **Cleanup**: DynamoDB TTL automatically deletes old records

## API Endpoint

**URL**: `POST /webhook/{callback_token}`

**Path Parameters**:

- `callback_token` (required) - Unique callback identifier

**Request Body** (from RunPod):

```json
{
  "id": "job-123",
  "status": "COMPLETED",
  "output": {
    "message": "Job completed successfully"
  }
}
```

or

```json
{
  "id": "job-123",
  "status": "FAILED",
  "error": "Out of memory"
}
```

**Responses**:

- `200 OK` - Webhook processed successfully
- `200 OK` (idempotent) - Already completed
- `404 Not Found` - Callback token not found
- `400 Bad Request` - Invalid request
- `410 Gone` - Task token expired
- `500 Internal Server Error` - Processing error

## Environment Variables

- `CALLBACK_TABLE_NAME` (required) - DynamoDB table name
- `LOG_LEVEL` (optional) - Logging level (default: INFO)

## IAM Permissions

Lambda requires:

- `states:SendTaskSuccess` - Resume Step Functions on success
- `states:SendTaskFailure` - Resume Step Functions on failure
- `dynamodb:GetItem` - Lookup callback records
- `dynamodb:UpdateItem` - Update completion status

## Testing

```bash
# Create a test callback record in DynamoDB first
aws dynamodb put-item --table-name dev-runpod-callbacks \
  --item '{
    "callback_token": {"S": "test-123"},
    "task_token": {"S": "AAAA...your-task-token..."},
    "job_id": {"S": "runpod-job-123"},
    "exec_id": {"S": "exec-123"},
    "segment_filename": {"S": "seg_0001.mp4"},
    "status": {"S": "PENDING"},
    "created_at": {"S": "2026-01-06T12:00:00Z"}
  }'

# Test webhook callback
curl -X POST https://your-api.execute-api.us-east-1.amazonaws.com/webhook/test-123 \
  -H "Content-Type: application/json" \
  -d '{
    "id": "runpod-job-123",
    "status": "COMPLETED",
    "output": {
      "message": "Video upscaled successfully"
    }'
```

## Monitoring

**CloudWatch Metrics**:

- Lambda invocation count
- Lambda error count
- Lambda duration

**CloudWatch Logs**:

- Request/response details
- DynamoDB lookup results
- Step Functions callback results
- Error traces

**Key Log Messages**:

- `Processing RunPod job {job_id} with status {status} for callback {callback_token}`
- `Callback token {callback_token} not found in DynamoDB`
- `Callback {callback_token} already completed, returning success`
- `Sent TaskSuccess for job {job_id}`
- `Sent TaskFailure for job {job_id}: {error}`
- `Task token expired for callback {callback_token}`
