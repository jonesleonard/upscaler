"""
Submit RunPod Job Lambda - Submits video upscaling jobs to RunPod with webhook callbacks.

This Lambda is called by Step Functions to:
1. Generate a unique callback token
2. Submit job to RunPod with presigned S3 URLs and webhook URL
3. Store callback mapping in DynamoDB for webhook handler to resume execution

Flow:
    Step Functions → Lambda (with task token + presigned URLs) → RunPod → Webhook → Resume Step Functions
"""

import json
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from urllib.parse import urljoin

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# AWS clients
dynamodb = boto3.resource("dynamodb")
secretsmanager_client = boto3.client("secretsmanager")

# Environment variables
CALLBACK_TABLE_NAME = os.environ["CALLBACK_TABLE_NAME"]
WEBHOOK_BASE_URL = os.environ["WEBHOOK_BASE_URL"]
RUNPOD_API_KEY_SECRET_NAME = os.environ["RUNPOD_API_KEY_SECRET_NAME"]

table = dynamodb.Table(CALLBACK_TABLE_NAME)

# Cache for API key (loaded once per Lambda container)
_runpod_api_key_cache: Optional[str] = None


def get_runpod_api_key() -> str:
    """
    Retrieve RunPod API key from AWS Secrets Manager with caching.
    
    The API key is cached for the lifetime of the Lambda container
    to avoid repeated Secrets Manager calls.
    
    Returns:
        RunPod API key string
        
    Raises:
        RuntimeError: If unable to retrieve the secret
    """
    global _runpod_api_key_cache
    
    if _runpod_api_key_cache is not None:
        return _runpod_api_key_cache
    
    logger.info(f"Fetching RunPod API key from Secrets Manager: {RUNPOD_API_KEY_SECRET_NAME}")
    
    try:
        response = secretsmanager_client.get_secret_value(
            SecretId=RUNPOD_API_KEY_SECRET_NAME
        )
        
        # Handle both string and JSON-encoded secrets
        if "SecretString" in response:
            secret_string = response["SecretString"]
            try:
                # Try parsing as JSON first (e.g., {"RUNPOD_API_KEY": "value"})
                secret_dict = json.loads(secret_string)
                # Look for common key names
                api_key = secret_dict.get("RUNPOD_API_KEY") or secret_dict.get("api_key") or secret_dict.get("key")
                if not api_key:
                    # If no recognized keys, use the first value
                    api_key = next(iter(secret_dict.values()))
            except (json.JSONDecodeError, StopIteration):
                # Not JSON, use the string directly
                api_key = secret_string
        else:
            raise RuntimeError("Secret does not contain SecretString")
        
        if not api_key:
            raise RuntimeError("API key is empty")
        
        _runpod_api_key_cache = api_key
        logger.info("RunPod API key retrieved and cached successfully")
        return api_key
        
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        logger.error(f"Error retrieving RunPod API key from Secrets Manager: {error_code}")
        raise RuntimeError(f"Failed to retrieve RunPod API key: {error_code}")
    except Exception as e:
        logger.error(f"Unexpected error retrieving RunPod API key: {e}")
        raise RuntimeError(f"Failed to retrieve RunPod API key: {e}")


def generate_callback_token() -> str:
    """
    Generate a secure random callback token.
    
    Returns:
        64-character hex string (32 bytes)
    """
    return secrets.token_hex(32)


def submit_runpod_job(
    input_url: str,
    output_url: str,
    webhook_url: str,
    rundpod_endpoint_url: str,
    params: dict[str, Any]
) -> str:
    """
    Submit job to RunPod with webhook callback.
    
    Args:
        input_url: Presigned S3 URL for input
        output_url: Presigned S3 URL for output
        webhook_url: Webhook callback URL
        rundpod_endpoint_url: RunPod job submission endpoint
        params: Upscale parameters (model, resolution, etc.)
        
    Returns:
        RunPod job ID
    """
    import requests
    
    logger.info(f"Submitting job to RunPod endpoint: {rundpod_endpoint_url}")
    
    payload = {
        "input": {
            "input_presigned_url": input_url,
            "output_presigned_url": output_url,
            "params": params
        },
        "webhook": webhook_url
    }
    
    headers = {
        "Authorization": f"Bearer {get_runpod_api_key()}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(
            rundpod_endpoint_url,
            json=payload,
            headers=headers,
            timeout=30
        )
        response.raise_for_status()
        
        result = response.json()
        job_id = result.get("id")
        
        if not job_id:
            raise RuntimeError(f"No job ID in RunPod response: {result}")
        
        logger.info(f"RunPod job submitted successfully: {job_id}")
        return job_id
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error submitting to RunPod: {e}")
        if hasattr(e.response, 'text'):
            logger.error(f"Response: {e.response.text}")
        raise RuntimeError(f"Failed to submit RunPod job: {e}")


def store_callback_mapping(
    callback_token: str,
    task_token: str,
    exec_id: str,
    segment_filename: str,
    job_id: str,
    ttl_hours: int = 168  # 7 days
) -> None:
    """
    Store callback token mapping in DynamoDB.
    
    Args:
        callback_token: Unique callback identifier
        task_token: Step Functions task token
        exec_id: Execution ID
        segment_filename: Segment filename
        job_id: RunPod job ID
        ttl_hours: TTL in hours (default 7 days)
    """
    logger.info(f"Storing callback mapping: token={callback_token}, job={job_id}")
    
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=ttl_hours)
    
    try:
        table.put_item(
            Item={
                "callback_token": callback_token,
                "task_token": task_token,
                "job_id": job_id,
                "exec_id": exec_id,
                "segment_filename": segment_filename,
                "status": "PENDING",
                "created_at": now.isoformat(),
                "expires_at": expires_at.isoformat(),
                "ttl": int(expires_at.timestamp())  # For DynamoDB TTL
            }
        )
        logger.info(f"Callback mapping stored successfully")
        
    except ClientError as e:
        logger.error(f"Error storing callback mapping: {e}")
        raise


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Lambda handler for submitting RunPod jobs with webhook callbacks.
    
    Expected input from Step Functions:
    {
        "exec_id": "execution-id",
        "task_token": "$$.Task.Token",
        "input_presigned_url": "https://s3.../seg_0001.mp4?...",
        "output_presigned_url": "https://s3.../seg_0001.mp4?...",
        "segment": {
            "index": 0,
            "filename": "seg_0000.mp4",
            "s3_uri": "s3://bucket/runs/1234/raw/seg_0000.mp4"
        },
        "runpod": {
            "run_endpoint": "https://api.runpod.ai/v2/1234/run",
        },
        "upscale": {
            "model": "seedvr2_ema_7b_fp16",
            "resolution": 1080,
            "batch_size_strategy": "quality",
            ...
        }
    }
    
    Returns:
    {
        "callback_token": "abc123...",
        "job_id": "runpod-job-123",
        "webhook_url": "https://api.../webhook/abc123"
    }
    """
    logger.info(f"Received event: {json.dumps(event, default=str)}")
    
    try:
        # Extract required fields
        task_token = event.get("task_token")
        if not task_token:
            raise ValueError("Missing required field: task_token")
        
        exec_id = event.get("exec_id")
        if not exec_id:
            raise ValueError("Missing required field: exec_id")
        
        segment = event.get("segment", {})
        segment_filename = segment.get("filename")
        if not segment_filename:
            raise ValueError("Missing required field: segment.filename")
        
        input_presigned_url = event.get("input_presigned_url")
        output_presigned_url = event.get("output_presigned_url")
        
        if not input_presigned_url or not output_presigned_url:
            raise ValueError("Missing required fields: input_presigned_url, output_presigned_url")
        
        runpod_endpoint_url = event.get("runpod", {}).get("run_endpoint")
        if not runpod_endpoint_url:
            raise ValueError("Missing required field: runpod.run_endpoint")
        
        params = event.get("params", {})
        
        # 1. Generate callback token
        callback_token = generate_callback_token()
        logger.info(f"Generated callback token: {callback_token}")
        
        # 2. Build webhook URL
        webhook_url = urljoin(WEBHOOK_BASE_URL, callback_token)
        logger.info(f"Webhook URL: {webhook_url}")
        
        # 3. Submit to RunPod
        job_id = submit_runpod_job(
            input_url=input_presigned_url,
            output_url=output_presigned_url,
            webhook_url=webhook_url,
            rundpod_endpoint_url=runpod_endpoint_url,
            params=params
        )
        
        # 4. Store callback mapping in DynamoDB
        store_callback_mapping(
            callback_token=callback_token,
            task_token=task_token,
            exec_id=exec_id,
            segment_filename=segment_filename,
            job_id=job_id
        )
        
        # 5. Return quickly
        response = {
            "callback_token": callback_token,
            "job_id": job_id,
            "webhook_url": webhook_url,
            "segment_filename": segment_filename,
            "exec_id": exec_id
        }
        
        logger.info(f"Job submitted successfully: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.exception(f"Error submitting RunPod job: {e}")
        raise
