"""
RunPod Webhook Handler - Receives callbacks from RunPod and resumes Step Functions.

This Lambda receives webhook callbacks from RunPod when jobs complete,
looks up the Step Functions task token from DynamoDB, then calls
SendTaskSuccess or SendTaskFailure to resume the waiting execution.

DynamoDB Schema:
    PK: callback_token (string)
    Attributes:
        - task_token (string) - Step Functions task token
        - job_id (string) - RunPod job ID
        - exec_id (string) - Execution ID
        - segment_filename (string) - Segment filename
        - status (string) - PENDING | COMPLETED | FAILED
        - created_at (string) - ISO timestamp
        - completed_at (string, optional) - ISO timestamp
        - result (map, optional) - Job result metadata
"""

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Optional

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

sfn_client = boto3.client("stepfunctions")
dynamodb = boto3.resource("dynamodb")

# Get table name from environment
TABLE_NAME = os.environ["CALLBACK_TABLE_NAME"]
table = dynamodb.Table(TABLE_NAME)


def get_callback_record(callback_token: str) -> Optional[dict[str, Any]]:
    """
    Retrieve callback record from DynamoDB.
    
    Args:
        callback_token: Unique callback token
        
    Returns:
        DynamoDB item or None if not found
    """
    try:
        response = table.get_item(Key={"callback_token": callback_token})
        return response.get("Item")
    except ClientError as e:
        logger.error(f"Error retrieving callback record: {e}")
        raise


def update_callback_completed(
    callback_token: str,
    status: str,
    result: Optional[dict[str, Any]] = None
) -> None:
    """
    Update callback record with completion status.
    
    Args:
        callback_token: Unique callback token
        status: COMPLETED or FAILED
        result: Optional result metadata
    """
    try:
        update_expr = "SET #status = :status, completed_at = :completed_at"
        expr_attr_names = {"#status": "status"}
        expr_attr_values = {
            ":status": status,
            ":completed_at": datetime.now(timezone.utc).isoformat()
        }
        
        if result:
            update_expr += ", #result = :result"
            expr_attr_names["#result"] = "result"
            expr_attr_values[":result"] = result
        
        table.update_item(
            Key={"callback_token": callback_token},
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values
        )
        logger.info(f"Updated callback record {callback_token} to status {status}")
    except ClientError as e:
        logger.error(f"Error updating callback record: {e}")
        raise

def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """
    Handle RunPod webhook callback.
    
    Expected URL: POST /webhook/{callback_token}
    
    Expected payload from RunPod:
    {
        "id": "job-id",
        "status": "COMPLETED" | "FAILED" | "CANCELLED" | "TIMED_OUT",
        "output": { ... },  # Present on success
        "error": "..."      # Present on failure
    }
    """
    logger.info(f"Received webhook event: {json.dumps(event)}")
    
    try:
        # Extract callback_token from path parameters
        path_params = event.get("pathParameters", {}) or {}
        callback_token = path_params.get("callback_token")
        
        if not callback_token:
            logger.error("No callback_token in path parameters")
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing callback_token in path"})
            }
        
        # Parse the incoming request body
        if "body" in event:
            body = json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]
        else:
            body = event
        
        job_id = body.get("id", "unknown")
        status = body.get("status", "UNKNOWN")
        
        logger.info(f"Processing RunPod job {job_id} with status {status} for callback {callback_token}")
        
        # 1. Lookup DynamoDB record
        record = get_callback_record(callback_token)
        
        if not record:
            logger.warning(f"Callback token {callback_token} not found in DynamoDB")
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "Callback token not found"})
            }
        
        # 2. Check if already completed (idempotent)
        if record.get("status") in ("COMPLETED", "FAILED"):
            logger.info(f"Callback {callback_token} already {record.get('status')}, returning 200 back to RunPod")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": "Callback already processed",
                    "completed_at": record.get("completed_at")
                })
            }
        
        task_token = record.get("task_token")
        if not task_token:
            logger.error(f"No task_token found in record for callback {callback_token}")
            return {
                "statusCode": 500,
                "body": json.dumps({"error": "Missing task_token in record"})
            }
        
        # 3. Process based on RunPod status
        if status == "COMPLETED":
            # Job succeeded - resume Step Functions with success
            output = {
                "job_id": job_id,
                "status": status,
                "callback_token": callback_token,
                "exec_id": record.get("exec_id"),
                "segment_filename": record.get("segment_filename"),
                "output": body.get("output", {})
            }
            
            try:
                sfn_client.send_task_success(
                    taskToken=task_token,
                    output=json.dumps(output)
                )
                logger.info(f"Sent TaskSuccess for job {job_id}")
                
                # 4. Update DynamoDB with completion
                update_callback_completed(
                    callback_token=callback_token,
                    status="COMPLETED",
                    result={
                        "job_id": job_id,
                        "runpod_status": status,
                        "output": body.get("output", {})
                    }
                )
                
            except sfn_client.exceptions.TaskTimedOut:
                logger.error(f"Task token expired for callback {callback_token}")
                # Still update DynamoDB to mark as completed
                update_callback_completed(
                    callback_token=callback_token,
                    status="COMPLETED",
                    result={"error": "Task token expired", "job_id": job_id}
                )
                return {
                    "statusCode": 410,
                    "body": json.dumps({"error": "Task token expired"})
                }
            except sfn_client.exceptions.InvalidToken:
                logger.error(f"Invalid task token for callback {callback_token}")
                update_callback_completed(
                    callback_token=callback_token,
                    status="FAILED",
                    result={"error": "Invalid task token", "job_id": job_id}
                )
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": "Invalid task token"})
                }
            
        elif status in ["FAILED", "CANCELLED", "TIMED_OUT"]:
            # Job failed - resume Step Functions with failure
            error_message = body.get("error", f"RunPod job {status}")
            error_code = f"RunPod{status.replace('_', '')}"
            
            try:
                sfn_client.send_task_failure(
                    taskToken=task_token,
                    error=error_code,
                    cause=error_message
                )
                logger.info(f"Sent TaskFailure for job {job_id}: {error_message}")
                
                # 4. Update DynamoDB with failure
                update_callback_completed(
                    callback_token=callback_token,
                    status="FAILED",
                    result={
                        "job_id": job_id,
                        "runpod_status": status,
                        "error": error_message
                    }
                )
                
            except sfn_client.exceptions.TaskTimedOut:
                logger.error(f"Task token expired for callback {callback_token}")
                update_callback_completed(
                    callback_token=callback_token,
                    status="FAILED",
                    result={"error": "Task token expired", "job_id": job_id}
                )
                return {
                    "statusCode": 410,
                    "body": json.dumps({"error": "Task token expired"})
                }
            except sfn_client.exceptions.InvalidToken:
                logger.error(f"Invalid task token for callback {callback_token}")
                update_callback_completed(
                    callback_token=callback_token,
                    status="FAILED",
                    result={"error": "Invalid task token", "job_id": job_id}
                )
                return {
                    "statusCode": 400,
                    "body": json.dumps({"error": "Invalid task token"})
                }
            
        else:
            # Unexpected status - log but return success (don't retry)
            logger.warning(f"Unexpected status '{status}' for job {job_id}, ignoring")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": f"Ignored unexpected status: {status}"
                })
            }
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Webhook processed successfully",
                "job_id": job_id,
                "status": status
            })
        }
        
    except Exception as e:
        logger.exception(f"Error processing webhook: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }