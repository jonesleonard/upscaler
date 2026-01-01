#!/usr/bin/env python3
"""
Lambda handler for generating presigned S3 URLs.
"""

import json
import os
from typing import Any, Dict

import boto3

DEFAULT_EXPIRES_SECONDS = 6 * 60 * 60
EXPIRES_ENV_VAR = "PRESIGN_EXPIRES_SECONDS"

_S3_CLIENT = boto3.client("s3")


def _parse_event(event: Any) -> Dict[str, Any]:
    if event is None:
        return {}
    if isinstance(event, str):
        try:
            return json.loads(event)
        except json.JSONDecodeError as exc:
            raise ValueError("Event string must be JSON.") from exc
    if isinstance(event, dict):
        body = event.get("body")
        if isinstance(body, str):
            try:
                parsed_body = json.loads(body)
            except json.JSONDecodeError:
                parsed_body = {}
            if isinstance(parsed_body, dict):
                merged = dict(event)
                merged.pop("body", None)
                merged.update(parsed_body)
                return merged
        return event
    raise ValueError("Event must be a dict or JSON string.")


def _coerce_int(value: Any, field_name: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field_name} must be an integer.") from exc


def _get_expires_seconds(event: Dict[str, Any]) -> int:
    event_override = event.get("presign_expires")
    if event_override is not None:
        expires = _coerce_int(event_override, "presign_expires")
    else:
        env_override = os.environ.get(EXPIRES_ENV_VAR)
        expires = _coerce_int(env_override, EXPIRES_ENV_VAR) if env_override else None
    if expires is None:
        expires = DEFAULT_EXPIRES_SECONDS
    if expires <= 0:
        raise ValueError("presign_expires must be positive.")
    return expires


def _require_field(event: Dict[str, Any], field: str) -> str:
    value = event.get(field)
    if not value:
        raise ValueError(f"Missing required field: {field}")
    return value


def _presign_get(bucket: str, key: str, expires: int) -> str:
    return _S3_CLIENT.generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=expires,
    )

def _presign_put(
    bucket: str,
    key: str,
    expires: int,
    server_side_encryption: str = None,
    content_type: str = None,
) -> str:
    """
    Generate a presigned PUT URL for uploading to S3.
    
    Parameters:
    bucket (str): The S3 bucket name.
    key (str): The S3 object key.
    expires (int): Expiration time in seconds.
    server_side_encryption (str): Optional server-side encryption (e.g., 'AES256', 'aws:kms').
    content_type (str): Optional content type for the upload.
    
    Returns:
    str: The presigned URL.
    """
    params = {"Bucket": bucket, "Key": key}
    
    if server_side_encryption:
        params["ServerSideEncryption"] = server_side_encryption
    
    if content_type:
        params["ContentType"] = content_type
    
    return _S3_CLIENT.generate_presigned_url(
        "put_object",
        Params=params,
        ExpiresIn=expires,
    )


def _process_single_request(
    request: Dict[str, Any],
    default_expires: int,
) -> Dict[str, Any]:
    """
    Process a single presigning request.
    
    Parameters:
    request (dict): The request containing bucket, key, operation, and options.
    default_expires (int): Default expiration time in seconds.
    
    Returns:
    dict: Result containing the presigned URL or error information.
    """
    try:
        bucket = _require_field(request, "bucket")
        key = _require_field(request, "key")
        operation = _require_field(request, "operation").lower()
        
        # Get expiration time (request-specific or default)
        expires = request.get("expires", default_expires)
        expires = _coerce_int(expires, "expires")
        
        if expires <= 0:
            raise ValueError("expires must be positive.")
        
        # Generate presigned URL based on operation type
        if operation == "get":
            url = _presign_get(bucket, key, expires)
        elif operation == "put":
            server_side_encryption = request.get("server_side_encryption")
            content_type = request.get("content_type")
            url = _presign_put(
                bucket,
                key,
                expires,
                server_side_encryption,
                content_type,
            )
        else:
            raise ValueError(f"Invalid operation: {operation}. Must be 'get' or 'put'.")
        
        return {
            "success": True,
            "bucket": bucket,
            "key": key,
            "operation": operation,
            "url": url,
            "expires_in": expires,
        }
    
    except Exception as exc:
        return {
            "success": False,
            "error": str(exc),
            "request": request,
        }


def lambda_handler(event: Any, context: Any) -> Dict[str, Any]:
    """
    Lambda handler for generating presigned S3 URLs.
    
    Expects an event with a 'requests' field containing an array of presigning requests.
    Each request should have: bucket, key, operation (get/put), optional expires,
    and for PUT operations: optional server_side_encryption and content_type.
    
    Parameters:
    event (Any): The Lambda event (can be a dict or JSON string).
    context (Any): The Lambda context object.
    
    Returns:
    dict: Response containing status code, body with results array.
    """
    try:
        payload = _parse_event(event)
        
        # Get default expiration time
        default_expires = _get_expires_seconds(payload)
        
        # Get the array of requests
        requests = payload.get("requests")
        if not requests:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "error": "Missing required field: requests",
                }),
            }
        
        if not isinstance(requests, list):
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "error": "Field 'requests' must be an array",
                }),
            }
        
        # Process each request
        results = [
            _process_single_request(req, default_expires)
            for req in requests
        ]
        
        # Check if any requests failed
        failed_count = sum(1 for r in results if not r.get("success"))
        success_count = len(results) - failed_count
        
        return {
            "statusCode": 200 if failed_count == 0 else 207,  # 207 Multi-Status if partial success
            "body": json.dumps({
                "results": results,
                "summary": {
                    "total": len(results),
                    "successful": success_count,
                    "failed": failed_count,
                },
            }),
        }
    
    except Exception as exc:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": f"Internal error: {str(exc)}",
            }),
        }
