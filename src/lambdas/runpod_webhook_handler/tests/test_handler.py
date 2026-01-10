"""
Unit tests for RunPod Webhook Handler Lambda.

Tests webhook processing logic, DynamoDB integration, and Step Functions resumption.
"""

import json
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest

import index


@pytest.fixture
def dynamodb_table():
    """Mock DynamoDB table."""
    table = MagicMock()
    table.get_item = MagicMock()
    table.update_item = MagicMock()
    return table


@pytest.fixture
def sfn_client():
    """Mock Step Functions client."""
    client = MagicMock()
    client.send_task_success = MagicMock()
    client.send_task_failure = MagicMock()
    return client


@pytest.fixture
def sample_event():
    """Sample webhook event from API Gateway."""
    return {
        "pathParameters": {
            "callback_token": "abc123token456"
        },
        "body": json.dumps({
            "id": "runpod-job-789",
            "status": "COMPLETED",
            "output": {
                "upscaled_url": "s3://bucket/output.mp4",
                "duration": 120.5
            }
        })
    }


@pytest.fixture
def sample_db_record():
    """Sample DynamoDB record."""
    return {
        "callback_token": "abc123token456",
        "task_token": "sfn-task-token-xyz",
        "job_id": "runpod-job-789",
        "exec_id": "exec-12345",
        "segment_filename": "seg_0001.mp4",
        "status": "PENDING",
        "created_at": datetime.now(timezone.utc).isoformat()
    }


def test_successful_completed_webhook(dynamodb_table, sfn_client, sample_event, sample_db_record):
    """Test successful processing of COMPLETED webhook."""
    with patch("index.table", dynamodb_table), \
         patch("index.sfn_client", sfn_client):
        
        # Mock DynamoDB response
        dynamodb_table.get_item.return_value = {"Item": sample_db_record}
        
        # Execute handler
        response = index.lambda_handler(sample_event, None)
        
        # Assertions
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["message"] == "Webhook processed successfully"
        assert body["job_id"] == "runpod-job-789"
        assert body["status"] == "COMPLETED"
        
        # Verify Step Functions was called
        sfn_client.send_task_success.assert_called_once()
        call_args = sfn_client.send_task_success.call_args
        assert call_args.kwargs["taskToken"] == "sfn-task-token-xyz"
        
        output = json.loads(call_args.kwargs["output"])
        assert output["job_id"] == "runpod-job-789"
        assert output["status"] == "COMPLETED"
        assert output["segment_filename"] == "seg_0001.mp4"
        
        # Verify DynamoDB was updated
        dynamodb_table.update_item.assert_called_once()


def test_successful_failed_webhook(dynamodb_table, sfn_client, sample_db_record):
    """Test successful processing of FAILED webhook."""
    event = {
        "pathParameters": {"callback_token": "abc123token456"},
        "body": json.dumps({
            "id": "runpod-job-789",
            "status": "FAILED",
            "error": "GPU out of memory"
        })
    }
    
    with patch("index.table", dynamodb_table), \
         patch("index.sfn_client", sfn_client):
        
        dynamodb_table.get_item.return_value = {"Item": sample_db_record}
        
        response = index.lambda_handler(event, None)
        
        # Assertions
        assert response["statusCode"] == 200
        
        # Verify Step Functions failure was sent
        sfn_client.send_task_failure.assert_called_once()
        call_args = sfn_client.send_task_failure.call_args
        assert call_args.kwargs["taskToken"] == "sfn-task-token-xyz"
        assert call_args.kwargs["error"] == "RunPodFAILED"
        assert "GPU out of memory" in call_args.kwargs["cause"]
        
        # Verify DynamoDB was updated with failure
        dynamodb_table.update_item.assert_called_once()


def test_missing_callback_token(dynamodb_table, sfn_client):
    """Test handling of missing callback token in path."""
    event = {
        "pathParameters": {},
        "body": json.dumps({"id": "job-123", "status": "COMPLETED"})
    }
    
    with patch("index.table", dynamodb_table), \
         patch("index.sfn_client", sfn_client):
        
        response = index.lambda_handler(event, None)
        
        # Assertions
        assert response["statusCode"] == 400
        body = json.loads(response["body"])
        assert "Missing callback_token" in body["error"]
        
        # Verify no Step Functions or DynamoDB calls
        sfn_client.send_task_success.assert_not_called()
        dynamodb_table.get_item.assert_not_called()


def test_callback_token_not_found(dynamodb_table, sfn_client, sample_event):
    """Test handling of callback token not found in DynamoDB."""
    with patch("index.table", dynamodb_table), \
         patch("index.sfn_client", sfn_client):
        
        # Mock DynamoDB returning no item
        dynamodb_table.get_item.return_value = {}
        
        response = index.lambda_handler(sample_event, None)
        
        # Assertions
        assert response["statusCode"] == 404
        body = json.loads(response["body"])
        assert "not found" in body["error"]
        
        # Verify no Step Functions calls
        sfn_client.send_task_success.assert_not_called()


def test_idempotent_already_processed(dynamodb_table, sfn_client, sample_event, sample_db_record):
    """Test idempotent handling of already processed callback."""
    # Mark record as already completed
    sample_db_record["status"] = "COMPLETED"
    sample_db_record["completed_at"] = datetime.now(timezone.utc).isoformat()
    
    with patch("index.table", dynamodb_table), \
         patch("index.sfn_client", sfn_client):
        
        dynamodb_table.get_item.return_value = {"Item": sample_db_record}
        
        response = index.lambda_handler(sample_event, None)
        
        # Assertions
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert "already processed" in body["message"]
        
        # Verify Step Functions was NOT called (idempotent)
        sfn_client.send_task_success.assert_not_called()
        sfn_client.send_task_failure.assert_not_called()
