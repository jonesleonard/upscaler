################################################################################
# Resource Group Outputs
################################################################################

output "resource_group_arn" {
  description = "The ARN of the resource group"
  value       = module.resource_group.arn
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.resource_group.name
}

################################################################################
# S3 Bucket Outputs
################################################################################

output "s3_bucket_arn" {
  description = "The ARN of the main S3 bucket."
  value       = module.s3.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "The bucket domain name of the main S3 bucket."
  value       = module.s3.bucket_domain_name
}

output "s3_bucket_id" {
  description = "The name/ID of the main S3 bucket."
  value       = module.s3.bucket_id
}

output "s3_bucket_region" {
  description = "The AWS region the main S3 bucket resides in."
  value       = module.s3.bucket_region
}

output "s3_logging_bucket_arn" {
  description = "The ARN of the S3 logging bucket."
  value       = module.s3.logging_bucket_arn
}

output "s3_logging_bucket_id" {
  description = "The name/ID of the S3 logging bucket."
  value       = module.s3.logging_bucket_id
}

################################################################################
# ECR Repository Outputs
################################################################################

# SPLITTER REPOSITORY

output "ecr_splitter_repository_name" {
  description = "The name of the splitter ECR repository."
  value       = module.ecr.splitter_repository_name
}

output "ecr_splitter_repository_arn" {
  description = "The ARN of the splitter ECR repository."
  value       = module.ecr.splitter_repository_arn
}

output "ecr_splitter_repository_url" {
  description = "The URL of the splitter ECR repository."
  value       = module.ecr.splitter_repository_url
}

# COMBINER REPOSITORY

output "ecr_combiner_repository_name" {
  description = "The name of the combiner ECR repository."
  value       = module.ecr.combiner_repository_name
}

output "ecr_combiner_repository_arn" {
  description = "The ARN of the combiner ECR repository."
  value       = module.ecr.combiner_repository_arn
}

output "ecr_combiner_repository_url" {
  description = "The URL of the combiner ECR repository."
  value       = module.ecr.combiner_repository_url
}

# UPSCALER REPOSITORY

output "ecr_upscaler_repository_name" {
  description = "The name of the upscaler ECR repository."
  value       = module.ecr.upscaler_repository_name
}

output "ecr_upscaler_repository_arn" {
  description = "The ARN of the upscaler ECR repository."
  value       = module.ecr.upscaler_repository_arn
}

output "ecr_upscaler_repository_url" {
  description = "The URL of the upscaler ECR repository."
  value       = module.ecr.upscaler_repository_url
}

################################################################################
# VPC Outputs
################################################################################

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = module.vpc.vpc_arn
}

output "vpc_batch_tasks_security_group_id" {
  description = "The ID of the security group for Batch tasks."
  value       = module.vpc.batch_tasks_security_group_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_intra_subnets" {
  description = "List of IDs of intra subnets in the VPC."
  value       = module.vpc.intra_subnets
}

################################################################################
# IAM Outputs
################################################################################

output "iam_batch_service_role_arn" {
  description = "The ARN of the AWS Batch service role."
  value       = module.iam.batch_service_role_arn
}

output "iam_ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = module.iam.ecs_task_execution_role_arn
}

output "iam_job_combine_role_arn" {
  description = "The ARN of the IAM role for the combine job."
  value       = module.iam.job_combine_role_arn
}

output "iam_job_split_role_arn" {
  description = "The ARN of the IAM role for the split job."
  value       = module.iam.job_split_role_arn
}

output "iam_job_upscale_role_arn" {
  description = "The ARN of the IAM role for the upscale job."
  value       = module.iam.job_upscale_role_arn
}

output "iam_job_upscale_runpod_role_arn" {
  description = "The ARN of the IAM role for the upscale RunPod job."
  value       = module.iam.job_upscale_runpod_role_arn
}

output "iam_presign_urls_lambda_role_arn" {
  description = "The ARN of the Lambda role for generating presigned S3 URLs."
  value       = module.iam.presign_urls_lambda_role_arn
}

################################################################################
# Batch Outputs
################################################################################

# Split Job Outputs

output "batch_split_job_definition_arn" {
  description = "The ARN of the split job definition."
  value       = module.batch.split_job_definition_arn
}

output "batch_split_job_definition_name" {
  description = "The name of the split job definition."
  value       = module.batch.split_job_definition_name
}

output "batch_split_job_queue_arn" {
  description = "The ARN of the split job queue."
  value       = module.batch.split_job_queue_arn
}

output "batch_split_job_queue_name" {
  description = "The name of the split job queue."
  value       = module.batch.split_job_queue_name
}

# Upscale Job Outputs

output "batch_upscale_job_definition_arn" {
  description = "The ARN of the upscale job definition."
  value       = module.batch.upscale_job_definition_arn
}

output "batch_upscale_job_definition_name" {
  description = "The name of the upscale job definition."
  value       = module.batch.upscale_job_definition_name
}

output "batch_upscale_job_queue_arn" {
  description = "The ARN of the upscale job queue."
  value       = module.batch.upscale_job_queue_arn
}

output "batch_upscale_job_queue_name" {
  description = "The name of the upscale job queue."
  value       = module.batch.upscale_job_queue_name
}

# Upscale RunPod Job Outputs

output "batch_upscale_runpod_job_definition_arn" {
  description = "The ARN of the upscale_runpod job definition."
  value       = module.batch.upscale_runpod_job_definition_arn
}

output "batch_upscale_runpod_job_definition_name" {
  description = "The name of the upscale_runpod job definition."
  value       = module.batch.upscale_runpod_job_definition_name
}

output "batch_upscale_runpod_job_queue_arn" {
  description = "The ARN of the upscale_runpod job queue."
  value       = module.batch.upscale_runpod_job_queue_arn
}

output "batch_upscale_runpod_job_queue_name" {
  description = "The name of the upscale_runpod job queue."
  value       = module.batch.upscale_runpod_job_queue_name
}

# Combine Job Outputs

output "batch_combine_job_definition_arn" {
  description = "The ARN of the combine job definition."
  value       = module.batch.combine_job_definition_arn
}

output "batch_combine_job_definition_name" {
  description = "The name of the combine job definition."
  value       = module.batch.combine_job_definition_name
}

output "batch_combine_job_queue_arn" {
  description = "The ARN of the combine job queue."
  value       = module.batch.combine_job_queue_arn
}

output "batch_combine_job_queue_name" {
  description = "The name of the combine job queue."
  value       = module.batch.combine_job_queue_name
}

################################################################################
# EventBridge Outputs
################################################################################

output "eventbridge_runpod_connection_arn" {
  description = "The ARN of the RunPod EventBridge connection."
  value       = module.eventbridge.runpod_connection_arn
  sensitive   = true
}

output "eventbridge_runpod_connection_name" {
  description = "The name of the RunPod EventBridge connection."
  value       = module.eventbridge.runpod_connection_name
}

################################################################################
# Step Functions Outputs
################################################################################

output "step_functions_upscale_video_state_machine_arn" {
  description = "The ARN of the Upscale Video Step Function state machine."
  value       = module.step_functions.upscale_video_state_machine_arn
}

output "step_functions_upscale_video_state_machine_name" {
  description = "The name of the Upscale Video Step Function state machine."
  value       = module.step_functions.upscale_video_state_machine_name
}

################################################################################
# Lambda Outputs
################################################################################

output "lambda_presign_urls_function_arn" {
  description = "The ARN of the Presign URLs Lambda function."
  value       = module.lambda.presign_model_urls_lambda_function_arn
}

output "lambda_presign_urls_function_name" {
  description = "The name of the Presign URLs Lambda function."
  value       = module.lambda.presign_model_urls_lambda_function_name
}

output "lambda_runpod_webhook_handler_function_arn" {
  description = "The ARN of the RunPod Webhook Handler Lambda function."
  value       = module.lambda.runpod_webhook_handler_lambda_function_arn
}

output "lambda_runpod_webhook_handler_function_name" {
  description = "The name of the RunPod Webhook Handler Lambda function."
  value       = module.lambda.runpod_webhook_handler_lambda_function_name
}

output "lambda_submit_runpod_job_function_arn" {
  description = "The ARN of the Submit RunPod Job Lambda function."
  value       = module.lambda.submit_runpod_job_lambda_function_arn
}

output "lambda_submit_runpod_job_function_name" {
  description = "The name of the Submit RunPod Job Lambda function."
  value       = module.lambda.submit_runpod_job_lambda_function_name
}

################################################################################
# API Gateway Outputs
################################################################################

output "api_gateway_runpod_webhook_handler_arn" {
  description = "The ARN of the RunPod Webhook Handler API Gateway."
  value       = module.api_gateway.runpod_webhook_handler_api_gateway_arn
}

output "api_gateway_runpod_webhook_handler_endpoint" {
  description = "The endpoint URL of the RunPod Webhook Handler API Gateway."
  value       = module.api_gateway.runpod_webhook_handler_api_gateway_endpoint
}

output "api_gateway_runpod_webhook_handler_name" {
  description = "The name of the RunPod Webhook Handler API Gateway."
  value       = module.api_gateway.runpod_webhook_handler_api_gateway_name
}

################################################################################
# DynamoDB Outputs
################################################################################

output "dynamodb_runpod_callbacks_table_arn" {
  description = "The ARN of the RunPod Callbacks DynamoDB table."
  value       = module.dynamodb.runpod_callbacks_table_arn
}

output "dynamodb_runpod_callbacks_table_name" {
  description = "The name of the RunPod Callbacks DynamoDB table."
  value       = module.dynamodb.runpod_callbacks_table_name
}
