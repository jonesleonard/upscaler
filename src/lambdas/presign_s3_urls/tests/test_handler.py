#!/usr/bin/env python3
"""
Tests for the presign S3 URLs Lambda handler using moto for S3 mocking.
"""

import json
import os
import sys
from pathlib import Path

import boto3
import pytest
from moto import mock_aws

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from index import (
    DEFAULT_EXPIRES_SECONDS,
    EXPIRES_ENV_VAR,
    _coerce_int,
    _get_expires_seconds,
    _parse_event,
    _presign_get,
    _presign_put,
    _process_single_request,
    _require_field,
    lambda_handler,
)


@pytest.fixture
def aws_credentials():
    """Mock AWS credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


@pytest.fixture
def s3_client(aws_credentials):
    """Create a mock S3 client."""
    with mock_aws():
        yield boto3.client("s3", region_name="us-east-1")


@pytest.fixture
def test_bucket(s3_client):
    """Create a test S3 bucket."""
    bucket_name = "test-bucket"
    s3_client.create_bucket(Bucket=bucket_name)
    return bucket_name


class TestParseEvent:
    """Tests for _parse_event function."""

    def test_parse_none(self):
        """Test parsing None returns empty dict."""
        assert _parse_event(None) == {}

    def test_parse_dict(self):
        """Test parsing a dict returns the dict."""
        event = {"key": "value"}
        assert _parse_event(event) == event

    def test_parse_json_string(self):
        """Test parsing a JSON string."""
        event = '{"key": "value"}'
        assert _parse_event(event) == {"key": "value"}

    def test_parse_invalid_json_string(self):
        """Test parsing an invalid JSON string raises ValueError."""
        with pytest.raises(ValueError, match="Event string must be JSON"):
            _parse_event("not valid json")

    def test_parse_api_gateway_event(self):
        """Test parsing API Gateway event with body field."""
        event = {
            "httpMethod": "POST",
            "body": '{"requests": [{"bucket": "test"}]}',
        }
        result = _parse_event(event)
        assert "requests" in result
        assert result["requests"] == [{"bucket": "test"}]
        assert "httpMethod" in result

    def test_parse_invalid_type(self):
        """Test parsing invalid type raises ValueError."""
        with pytest.raises(ValueError, match="Event must be a dict or JSON string"):
            _parse_event(123)


class TestCoerceInt:
    """Tests for _coerce_int function."""

    def test_coerce_valid_int(self):
        """Test coercing valid integer."""
        assert _coerce_int(42, "field") == 42

    def test_coerce_string_int(self):
        """Test coercing string representation of integer."""
        assert _coerce_int("42", "field") == 42

    def test_coerce_invalid_string(self):
        """Test coercing invalid string raises ValueError."""
        with pytest.raises(ValueError, match="field must be an integer"):
            _coerce_int("not a number", "field")

    def test_coerce_none(self):
        """Test coercing None raises ValueError."""
        with pytest.raises(ValueError, match="field must be an integer"):
            _coerce_int(None, "field")


class TestGetExpiresSeconds:
    """Tests for _get_expires_seconds function."""

    def test_default_expires(self):
        """Test default expiration time."""
        # Clear env var if it exists
        os.environ.pop(EXPIRES_ENV_VAR, None)
        assert _get_expires_seconds({}) == DEFAULT_EXPIRES_SECONDS

    def test_event_override(self):
        """Test event-level override."""
        event = {"presign_expires": 1800}
        assert _get_expires_seconds(event) == 1800

    def test_event_override_string(self):
        """Test event-level override as string."""
        event = {"presign_expires": "3600"}
        assert _get_expires_seconds(event) == 3600

    def test_env_override(self, monkeypatch):
        """Test environment variable override."""
        monkeypatch.setenv(EXPIRES_ENV_VAR, "7200")
        assert _get_expires_seconds({}) == 7200

    def test_event_takes_precedence_over_env(self, monkeypatch):
        """Test event override takes precedence over env var."""
        monkeypatch.setenv(EXPIRES_ENV_VAR, "7200")
        event = {"presign_expires": 1800}
        assert _get_expires_seconds(event) == 1800

    def test_negative_expires_raises(self):
        """Test negative expires raises ValueError."""
        event = {"presign_expires": -100}
        with pytest.raises(ValueError, match="presign_expires must be positive"):
            _get_expires_seconds(event)

    def test_zero_expires_raises(self):
        """Test zero expires raises ValueError."""
        event = {"presign_expires": 0}
        with pytest.raises(ValueError, match="presign_expires must be positive"):
            _get_expires_seconds(event)


class TestRequireField:
    """Tests for _require_field function."""

    def test_require_existing_field(self):
        """Test requiring an existing field."""
        event = {"bucket": "my-bucket"}
        assert _require_field(event, "bucket") == "my-bucket"

    def test_require_missing_field(self):
        """Test requiring a missing field raises ValueError."""
        with pytest.raises(ValueError, match="Missing required field: bucket"):
            _require_field({}, "bucket")

    def test_require_empty_field(self):
        """Test requiring an empty field raises ValueError."""
        with pytest.raises(ValueError, match="Missing required field: bucket"):
            _require_field({"bucket": ""}, "bucket")


class TestPresignFunctionsWithMoto:
    """Tests for presigning functions using moto."""

    @mock_aws
    def test_presign_get_generates_valid_url(self, test_bucket):
        """Test generating presigned GET URL produces valid S3 URL."""
        # Reinitialize the S3 client within the mock context
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        
        # Create the bucket
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        # Put an object
        index._S3_CLIENT.put_object(
            Bucket=test_bucket,
            Key="test/file.mp4",
            Body=b"test content",
        )
        
        url = _presign_get(test_bucket, "test/file.mp4", 3600)
        
        # Verify URL structure
        assert test_bucket in url
        assert "test/file.mp4" in url
        assert "AWSAccessKeyId" in url or "X-Amz-" in url
        assert "Signature" in url or "X-Amz-Signature" in url

    @mock_aws
    def test_presign_put_generates_valid_url(self, test_bucket):
        """Test generating presigned PUT URL produces valid S3 URL."""
        # Reinitialize the S3 client within the mock context
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        
        # Create the bucket
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        url = _presign_put(test_bucket, "uploads/new-file.mp4", 3600)
        
        # Verify URL structure
        assert test_bucket in url
        assert "uploads/new-file.mp4" in url
        assert "AWSAccessKeyId" in url or "X-Amz-" in url

    @mock_aws
    def test_presign_put_with_encryption_option(self, test_bucket):
        """Test generating presigned PUT URL with encryption."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        url = _presign_put(
            test_bucket,
            "uploads/encrypted.mp4",
            3600,
            server_side_encryption="AES256",
        )
        
        assert test_bucket in url
        assert "uploads/encrypted.mp4" in url

    @mock_aws
    def test_presign_put_with_content_type(self, test_bucket):
        """Test generating presigned PUT URL with content type."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        url = _presign_put(
            test_bucket,
            "uploads/video.mp4",
            3600,
            content_type="video/mp4",
        )
        
        assert test_bucket in url
        assert "uploads/video.mp4" in url


class TestProcessSingleRequest:
    """Tests for _process_single_request function."""

    @mock_aws
    def test_process_get_request(self, test_bucket):
        """Test processing a GET request."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        index._S3_CLIENT.put_object(
            Bucket=test_bucket,
            Key="file.mp4",
            Body=b"content",
        )
        
        request = {
            "bucket": test_bucket,
            "key": "file.mp4",
            "operation": "get",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is True
        assert result["bucket"] == test_bucket
        assert result["key"] == "file.mp4"
        assert result["operation"] == "get"
        assert "url" in result
        assert result["expires_in"] == 3600

    @mock_aws
    def test_process_put_request(self, test_bucket):
        """Test processing a PUT request."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        request = {
            "bucket": test_bucket,
            "key": "uploads/file.mp4",
            "operation": "put",
            "server_side_encryption": "AES256",
            "content_type": "video/mp4",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is True
        assert result["operation"] == "put"
        assert "url" in result

    @mock_aws
    def test_process_request_with_custom_expires(self, test_bucket):
        """Test processing request with custom expiration."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        request = {
            "bucket": test_bucket,
            "key": "file.mp4",
            "operation": "get",
            "expires": 7200,
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is True
        assert result["expires_in"] == 7200

    def test_process_request_missing_bucket(self):
        """Test processing request with missing bucket."""
        request = {
            "key": "file.mp4",
            "operation": "get",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is False
        assert "Missing required field: bucket" in result["error"]
        assert result["request"] == request

    def test_process_request_missing_key(self):
        """Test processing request with missing key."""
        request = {
            "bucket": "my-bucket",
            "operation": "get",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is False
        assert "Missing required field: key" in result["error"]

    def test_process_request_missing_operation(self):
        """Test processing request with missing operation."""
        request = {
            "bucket": "my-bucket",
            "key": "file.mp4",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is False
        assert "Missing required field: operation" in result["error"]

    def test_process_request_invalid_operation(self):
        """Test processing request with invalid operation."""
        request = {
            "bucket": "my-bucket",
            "key": "file.mp4",
            "operation": "delete",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is False
        assert "Invalid operation: delete" in result["error"]

    @mock_aws
    def test_process_request_case_insensitive_operation(self, test_bucket):
        """Test processing request with uppercase operation."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        request = {
            "bucket": test_bucket,
            "key": "file.mp4",
            "operation": "GET",
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is True
        assert result["operation"] == "get"

    def test_process_request_negative_expires(self):
        """Test processing request with negative expiration."""
        request = {
            "bucket": "my-bucket",
            "key": "file.mp4",
            "operation": "get",
            "expires": -100,
        }
        
        result = _process_single_request(request, 3600)
        
        assert result["success"] is False
        assert "expires must be positive" in result["error"]


class TestLambdaHandler:
    """Tests for lambda_handler function."""

    @mock_aws
    def test_handler_single_request(self, test_bucket):
        """Test handler with single GET request."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        event = {
            "requests": [
                {
                    "bucket": test_bucket,
                    "key": "file.mp4",
                    "operation": "get",
                }
            ]
        }
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["summary"]["total"] == 1
        assert body["summary"]["successful"] == 1
        assert body["summary"]["failed"] == 0
        assert len(body["results"]) == 1
        assert body["results"][0]["success"] is True

    @mock_aws
    def test_handler_batch_requests(self, test_bucket):
        """Test handler with batch requests."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        event = {
            "requests": [
                {
                    "bucket": test_bucket,
                    "key": "file1.mp4",
                    "operation": "get",
                },
                {
                    "bucket": test_bucket,
                    "key": "file2.mp4",
                    "operation": "put",
                    "content_type": "video/mp4",
                },
                {
                    "bucket": test_bucket,
                    "key": "file3.mp4",
                    "operation": "get",
                },
            ]
        }
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["summary"]["total"] == 3
        assert body["summary"]["successful"] == 3
        assert body["summary"]["failed"] == 0

    @mock_aws
    def test_handler_partial_failure(self, test_bucket):
        """Test handler with partial failures."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        event = {
            "requests": [
                {
                    "bucket": test_bucket,
                    "key": "valid.mp4",
                    "operation": "get",
                },
                {
                    "key": "missing-bucket.mp4",
                    "operation": "get",
                },
            ]
        }
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 207  # Multi-Status
        body = json.loads(response["body"])
        assert body["summary"]["total"] == 2
        assert body["summary"]["successful"] == 1
        assert body["summary"]["failed"] == 1
        assert body["results"][0]["success"] is True
        assert body["results"][1]["success"] is False

    def test_handler_missing_requests_field(self):
        """Test handler with missing requests field."""
        event = {}
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 400
        body = json.loads(response["body"])
        assert "Missing required field: requests" in body["error"]

    def test_handler_requests_not_array(self):
        """Test handler with requests field not being an array."""
        event = {"requests": "not an array"}
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 400
        body = json.loads(response["body"])
        assert "Field 'requests' must be an array" in body["error"]

    @mock_aws
    def test_handler_with_api_gateway_event(self, test_bucket):
        """Test handler with API Gateway event structure."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        event = {
            "httpMethod": "POST",
            "body": json.dumps({
                "requests": [
                    {
                        "bucket": test_bucket,
                        "key": "file.mp4",
                        "operation": "get",
                    }
                ]
            })
        }
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["summary"]["successful"] == 1

    @mock_aws
    def test_handler_with_global_expires(self, test_bucket):
        """Test handler with global expiration override."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        index._S3_CLIENT.create_bucket(Bucket=test_bucket)
        
        event = {
            "presign_expires": 7200,
            "requests": [
                {
                    "bucket": test_bucket,
                    "key": "file.mp4",
                    "operation": "get",
                }
            ]
        }
        
        response = lambda_handler(event, None)
        
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["results"][0]["expires_in"] == 7200

    def test_handler_empty_requests_array(self):
        """Test handler with empty requests array."""
        event = {"requests": []}
        
        response = lambda_handler(event, None)
        
        # Empty array is falsy in Python, so treated as missing
        assert response["statusCode"] == 400
        body = json.loads(response["body"])
        assert "Missing required field: requests" in body["error"]


class TestIntegrationWithRealS3Calls:
    """Integration tests that verify the full flow with moto."""

    @mock_aws
    def test_full_workflow_get_presigned_url(self):
        """Test complete workflow for GET presigned URL generation."""
        # Initialize S3 client in mock environment
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        
        # Create bucket and upload file
        bucket_name = "integration-test-bucket"
        index._S3_CLIENT.create_bucket(Bucket=bucket_name)
        index._S3_CLIENT.put_object(
            Bucket=bucket_name,
            Key="videos/test.mp4",
            Body=b"video content",
        )
        
        # Make Lambda request
        event = {
            "requests": [
                {
                    "bucket": bucket_name,
                    "key": "videos/test.mp4",
                    "operation": "get",
                    "expires": 1800,
                }
            ]
        }
        
        response = lambda_handler(event, None)
        
        # Verify response
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["summary"]["successful"] == 1
        
        # Extract and verify URL
        presigned_url = body["results"][0]["url"]
        assert bucket_name in presigned_url
        assert "videos/test.mp4" in presigned_url

    @mock_aws
    def test_full_workflow_put_presigned_url(self):
        """Test complete workflow for PUT presigned URL generation."""
        import index
        index._S3_CLIENT = boto3.client("s3", region_name="us-east-1")
        
        # Create bucket
        bucket_name = "integration-test-bucket"
        index._S3_CLIENT.create_bucket(Bucket=bucket_name)
        
        # Make Lambda request
        event = {
            "requests": [
                {
                    "bucket": bucket_name,
                    "key": "uploads/new-video.mp4",
                    "operation": "put",
                    "server_side_encryption": "AES256",
                    "content_type": "video/mp4",
                    "expires": 3600,
                }
            ]
        }
        
        response = lambda_handler(event, None)
        
        # Verify response
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["summary"]["successful"] == 1
        
        # Extract and verify URL
        result = body["results"][0]
        assert result["success"] is True
        assert result["operation"] == "put"
        assert result["expires_in"] == 3600
        presigned_url = result["url"]
        assert bucket_name in presigned_url
        assert "uploads/new-video.mp4" in presigned_url
