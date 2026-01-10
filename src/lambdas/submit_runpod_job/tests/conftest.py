"""Pytest configuration and shared fixtures."""
import os
from unittest.mock import MagicMock, patch

import pytest

# Set environment variables before any imports
os.environ["CALLBACK_TABLE_NAME"] = "test-callback-table"
os.environ["WEBHOOK_BASE_URL"] = "https://api.example.com/webhook/"
os.environ["RUNPOD_API_KEY_SECRET_NAME"] = "test-runpod-secret"
os.environ["LOG_LEVEL"] = "INFO"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_REGION"] = "us-east-1"


# Mock boto3 at module level before index is imported anywhere
mock_dynamodb = MagicMock()
mock_table = MagicMock()
mock_table.put_item = MagicMock()
mock_dynamodb.Table.return_value = mock_table

mock_secrets_client = MagicMock()

with patch("boto3.resource", return_value=mock_dynamodb):
    with patch("boto3.client", return_value=mock_secrets_client):
        import index  # noqa: F401


@pytest.fixture
def reset_cache():
    """Reset API key cache between tests."""
    import index
    index._runpod_api_key_cache = None
    yield
    index._runpod_api_key_cache = None
