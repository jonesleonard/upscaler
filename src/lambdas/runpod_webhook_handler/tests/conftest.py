"""Pytest configuration and shared fixtures."""
import os
from unittest.mock import MagicMock, patch

# Set environment variables before any imports
os.environ["CALLBACK_TABLE_NAME"] = "test-callback-table"
os.environ["LOG_LEVEL"] = "INFO"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_REGION"] = "us-east-1"


# Mock boto3 at module level before index is imported anywhere
mock_dynamodb = MagicMock()
mock_table = MagicMock()
mock_table.get_item = MagicMock()
mock_table.update_item = MagicMock()
mock_dynamodb.Table.return_value = mock_table

mock_sfn_client = MagicMock()

with patch("boto3.resource", return_value=mock_dynamodb):
    with patch("boto3.client", return_value=mock_sfn_client):
        import index  # noqa: F401
