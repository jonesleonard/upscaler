"""
Unit tests for Submit RunPod Job Lambda.

Tests job submission logic, RunPod API integration, and DynamoDB callback storage.
"""

import json
from unittest.mock import MagicMock, patch

import pytest
from botocore.exceptions import ClientError

import index


@pytest.fixture
def dynamodb_table():
    """Mock DynamoDB table."""
    table = MagicMock()
    table.put_item = MagicMock()
    return table


@pytest.fixture
def secrets_client():
    """Mock Secrets Manager client."""
    client = MagicMock()
    client.get_secret_value = MagicMock(return_value={
        "SecretString": json.dumps({"RUNPOD_API_KEY": "test-api-key-123"})
    })
    return client


@pytest.fixture
def sample_event():
    """Sample event from Step Functions."""
    return {
        "exec_id": "exec-12345",
        "task_token": "sfn-task-token-xyz-abc",
        "input_presigned_url": "https://s3.amazonaws.com/bucket/input.mp4?signature=xyz",
        "output_presigned_url": "https://s3.amazonaws.com/bucket/output.mp4?signature=abc",
        "segment": {
            "index": 0,
            "filename": "seg_0000.mp4",
            "s3_uri": "s3://bucket/runs/1234/raw/seg_0000.mp4"
        },
        "runpod_endpoint": "https://api.runpod.ai/v2/endpoint123/run",
        "log_level": "DEBUG",
        "debug": True,
        "seed": 42,
        "color_correction": "lab",
        "model": "seedvr2_ema_7b_fp16",
        "resolution": 1080,
        "batch_size_strategy": "quality",
        "batch_size_explicit": "",
        "batch_size_conservative": 129,
        "batch_size_quality": 257,
        "chunk_size_strategy": "recommended",
        "chunk_size_explicit": 0,
        "chunk_size_recommended": 16,
        "chunk_size_fallback": 8,
        "attention_mode": "sageattn_2",
        "temporal_overlap": 4,
        "vae_encode_tiled": False,
        "vae_decode_tiled": False,
        "cache_dit": False,
        "cache_vae": False,
        "compile_dit": False,
        "compile_vae": False,
        "video_backend": "ffmpeg",
        "ten_bit": True
    }


@pytest.fixture
def mock_requests():
    """Mock requests library."""
    mock_req = MagicMock()
    mock_response = MagicMock()
    mock_response.json.return_value = {"id": "runpod-job-abc123"}
    mock_response.raise_for_status = MagicMock()
    mock_req.post.return_value = mock_response
    
    with patch("index.requests", mock_req):
        yield mock_req


def test_successful_job_submission(dynamodb_table, secrets_client, mock_requests, sample_event, reset_cache):
    """Test successful RunPod job submission."""
    with patch("index.table", dynamodb_table), \
         patch("index.secretsmanager_client", secrets_client), \
         patch("index._runpod_api_key_cache", "test-api-key-123"):
        
        response = index.lambda_handler(sample_event, None)
        
        # Assertions
        assert "callback_token" in response
        assert response["job_id"] == "runpod-job-abc123"
        assert response["segment_filename"] == "seg_0000.mp4"
        assert response["exec_id"] == "exec-12345"
        assert "webhook_url" in response
        
        # Verify RunPod API was called correctly
        mock_requests.post.assert_called_once()
        call_args = mock_requests.post.call_args
        assert call_args.args[0] == "https://api.runpod.ai/v2/endpoint123/run"
        
        payload = call_args.kwargs["json"]
        assert payload["input"]["input_presigned_url"] == sample_event["input_presigned_url"]
        assert payload["input"]["output_presigned_url"] == sample_event["output_presigned_url"]
        assert "webhookV2" in payload
        
        headers = call_args.kwargs["headers"]
        assert headers["Authorization"] == "Bearer test-api-key-123"
        
        # Verify DynamoDB was called
        dynamodb_table.put_item.assert_called_once()
        db_item = dynamodb_table.put_item.call_args.kwargs["Item"]
        assert db_item["task_token"] == "sfn-task-token-xyz-abc"
        assert db_item["job_id"] == "runpod-job-abc123"
        assert db_item["status"] == "PENDING"


def test_missing_task_token(dynamodb_table, secrets_client, sample_event, reset_cache):
    """Test error handling when task_token is missing."""
    # Remove task_token from event
    del sample_event["task_token"]
    
    with patch("index.table", dynamodb_table), \
         patch("index.secretsmanager_client", secrets_client):
        
        with pytest.raises(ValueError, match="Missing required field: task_token"):
            index.lambda_handler(sample_event, None)


def test_missing_segment_filename(dynamodb_table, secrets_client, sample_event, reset_cache):
    """Test error handling when segment filename is missing."""
    # Remove filename from segment
    del sample_event["segment"]["filename"]
    
    with patch("index.table", dynamodb_table), \
         patch("index.secretsmanager_client", secrets_client):
        
        with pytest.raises(ValueError, match="Missing required field: segment.filename"):
            index.lambda_handler(sample_event, None)


def test_runpod_api_error(dynamodb_table, secrets_client, sample_event, reset_cache):
    """Test error handling when RunPod API returns an error."""
    with patch("index.table", dynamodb_table), \
         patch("index.secretsmanager_client", secrets_client), \
         patch("index._runpod_api_key_cache", "test-api-key-123"):
        
        # Patch index.requests
        mock_req = MagicMock()
        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = Exception("API Error: 500")
        mock_response.text = "Internal Server Error"
        mock_req.post.return_value = mock_response
        
        with patch("index.requests", mock_req):
            with pytest.raises(Exception):
                index.lambda_handler(sample_event, None)


def test_dynamodb_error(dynamodb_table, secrets_client, mock_requests, sample_event, reset_cache):
    """Test error handling when DynamoDB fails to store callback."""
    with patch("index.table", dynamodb_table), \
         patch("index.secretsmanager_client", secrets_client), \
         patch("index._runpod_api_key_cache", "test-api-key-123"):
        
        # Mock DynamoDB error
        dynamodb_table.put_item.side_effect = ClientError(
            {"Error": {"Code": "ServiceUnavailable"}},
            "PutItem"
        )
        
        with pytest.raises(ClientError):
            index.lambda_handler(sample_event, None)

