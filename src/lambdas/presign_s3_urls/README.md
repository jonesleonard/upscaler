# Presign S3 URLs Lambda

AWS Lambda function for generating presigned S3 URLs for batch operations. Supports both GET (download) and PUT (upload) operations with flexible configuration options.

## Purpose

This Lambda handler processes batch requests to generate presigned URLs for S3 objects, enabling secure temporary access to private S3 resources without requiring AWS credentials.

## Request Format

The Lambda accepts an event with a `requests` array containing individual presigning requests.

### Event Structure

```json
{
  "requests": [
    {
      "bucket": "string (required)",
      "key": "string (required)",
      "operation": "get|put (required)",
      "expires": "integer (optional)",
      "server_side_encryption": "string (optional, PUT only)",
      "content_type": "string (optional, PUT only)"
    }
  ],
  "presign_expires": "integer (optional, global default)"
}
```

### Request Fields

#### Required Fields

- **`bucket`**: The S3 bucket name
- **`key`**: The S3 object key (path)
- **`operation`**: Either `"get"` (download) or `"put"` (upload)

#### Optional Fields

- **`expires`**: Expiration time in seconds for this specific request (overrides global default)
- **`server_side_encryption`**: Server-side encryption algorithm (PUT only)
  - Examples: `"AES256"`, `"aws:kms"`
- **`content_type`**: MIME type for the uploaded object (PUT only)
  - Examples: `"video/mp4"`, `"image/jpeg"`, `"application/json"`

#### Global Configuration

- **`presign_expires`**: Default expiration time in seconds for all requests (can be overridden per-request)
  - Falls back to environment variable `PRESIGN_EXPIRES_SECONDS` if not provided
  - Default: 21600 seconds (6 hours)

## Response Format

### Success Response (HTTP 200)

```json
{
  "statusCode": 200,
  "body": {
    "results": [
      {
        "success": true,
        "bucket": "my-bucket",
        "key": "path/to/file.mp4",
        "operation": "get",
        "url": "https://my-bucket.s3.amazonaws.com/path/to/file.mp4?...",
        "expires_in": 3600
      }
    ],
    "summary": {
      "total": 1,
      "successful": 1,
      "failed": 0
    }
  }
}
```

### Partial Success Response (HTTP 207 Multi-Status)

When some requests succeed and others fail:

```json
{
  "statusCode": 207,
  "body": {
    "results": [
      {
        "success": true,
        "bucket": "my-bucket",
        "key": "valid/file.mp4",
        "operation": "get",
        "url": "https://...",
        "expires_in": 3600
      },
      {
        "success": false,
        "error": "Missing required field: bucket",
        "request": { "key": "invalid/request.mp4" }
      }
    ],
    "summary": {
      "total": 2,
      "successful": 1,
      "failed": 1
    }
  }
}
```

### Error Response (HTTP 400/500)

```json
{
  "statusCode": 400,
  "body": {
    "error": "Missing required field: requests"
  }
}
```

## Examples

### Example 1: Generate Download URL

```json
{
  "requests": [
    {
      "bucket": "my-video-bucket",
      "key": "processed/output.mp4",
      "operation": "get",
      "expires": 7200
    }
  ]
}
```

### Example 2: Generate Upload URL with Encryption

```json
{
  "requests": [
    {
      "bucket": "my-video-bucket",
      "key": "uploads/input-video.mp4",
      "operation": "put",
      "server_side_encryption": "AES256",
      "content_type": "video/mp4",
      "expires": 3600
    }
  ]
}
```

### Example 3: Batch Processing

```json
{
  "presign_expires": 1800,
  "requests": [
    {
      "bucket": "my-bucket",
      "key": "uploads/segment-001.ts",
      "operation": "put",
      "content_type": "video/mp2t",
      "server_side_encryption": "AES256"
    },
    {
      "bucket": "my-bucket",
      "key": "uploads/segment-002.ts",
      "operation": "put",
      "content_type": "video/mp2t",
      "server_side_encryption": "AES256"
    },
    {
      "bucket": "my-bucket",
      "key": "reference/master.m3u8",
      "operation": "get"
    }
  ]
}
```

### Example 4: Using API Gateway

When invoked via API Gateway, the request is wrapped in an HTTP event:

```json
{
  "body": "{\"requests\":[{\"bucket\":\"my-bucket\",\"key\":\"file.mp4\",\"operation\":\"get\"}]}"
}
```

The handler automatically parses the `body` field and merges it with the event.

## Environment Variables

- **`PRESIGN_EXPIRES_SECONDS`**: Default expiration time in seconds (default: 21600 / 6 hours)
  - Can be overridden by event-level `presign_expires` or request-level `expires`

## IAM Permissions

The Lambda execution role requires the following S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket-name/*"
    }
  ]
}
```

## Error Handling

The Lambda uses per-request error handling:

- **Individual Request Failures**: Captured and returned in the results array with `success: false`
- **Global Failures**: Return HTTP 400 (bad request) or 500 (internal error)
- **Validation Errors**: Missing required fields, invalid types, or negative expiration times

Each failed request includes:

- `success: false`
- `error`: Error message describing the failure
- `request`: The original request object for debugging

## Deployment Notes

1. **Dependencies**: Requires `boto3` (included in AWS Lambda Python runtime)
2. **Runtime**: Python 3.9+ recommended
3. **Memory**: 128 MB should be sufficient for most use cases
4. **Timeout**: 30 seconds recommended for large batch operations

## Testing

The Lambda includes comprehensive unit and integration tests with 99% code coverage.

### Running Tests

1. **Install test dependencies**:

   ```bash
   pip install -r requirements-test.txt
   ```

2. **Run all tests**:

   ```bash
   pytest tests/ -v
   ```

3. **Run tests with coverage report**:

   ```bash
   pytest tests/ --cov=. --cov-report=term-missing
   ```

4. **Run specific test class**:

   ```bash
   pytest tests/test_handler.py::TestLambdaHandler -v
   ```

### Test Coverage

The test suite includes:

- **43 test cases** covering all major functionality
- **Event parsing** (dict, JSON string, API Gateway format)
- **Input validation** and error handling
- **Presigned URL generation** (GET/PUT with various options)
- **Batch processing** with partial failure handling
- **Integration tests** using moto for S3 mocking

All S3 operations are mocked using [moto](https://github.com/getmoto/moto), so no real AWS resources are required for testing.

## Use Cases

- **Video Processing**: Generate upload URLs for video segments and download URLs for processed output
- **Bulk Operations**: Process multiple presigning requests in a single invocation
- **Client-Side Uploads**: Enable browsers/mobile apps to upload directly to S3
- **Secure Downloads**: Provide time-limited access to private S3 content
