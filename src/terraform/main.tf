locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
    CreatedBy   = "Terraform"
    ManagedBy   = "Terraform"
  }
}

################################################################################
# Resource Group
################################################################################

module "resource_group" {
  source       = "./modules/resource_group"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags
}

################################################################################
# S3 Buckets
################################################################################

module "s3" {
  source       = "./modules/s3"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # Optional: Override defaults for lifecycle and CORS
  cors_allowed_origins                = var.cors_allowed_origins
  raw_files_expiration_days           = var.raw_files_expiration_days
  upscaled_files_expiration_days      = var.upscaled_files_expiration_days
  final_files_glacier_transition_days = var.final_files_glacier_transition_days
  log_retention_days                  = var.log_retention_days
}

################################################################################
# ECR Repositories
################################################################################

module "ecr" {
  source       = "./modules/ecr"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # Repository configuration
  repository_encryption_type      = var.ecr_repository_encryption_type
  repository_force_delete         = var.ecr_repository_force_delete
  repository_image_scan_on_push   = var.ecr_repository_image_scan_on_push
  repository_image_tag_mutability = var.ecr_repository_image_tag_mutability
  repository_kms_key              = var.ecr_repository_kms_key

  # Lifecycle policy configuration
  tag_prefix_list     = var.ecr_tag_prefix_list
  tagged_image_count  = var.ecr_tagged_image_count
  untagged_image_days = var.ecr_untagged_image_days
}

################################################################################
# VPC & Networking
################################################################################

module "vpc" {
  source       = "./modules/vpc"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # VPC configuration
  az_redundancy_level     = var.vpc_az_redundancy_level
  vpc_cidr                = var.vpc_cidr
  enable_flow_logs        = var.vpc_enable_flow_logs
  flow_log_retention_days = var.vpc_flow_log_retention_days
  flow_log_traffic_type   = var.vpc_flow_log_traffic_type

  # VPC endpoint configuration
  ecr_resource_arns = [
    module.ecr.splitter_repository_arn,
    module.ecr.upscaler_repository_arn,
    module.ecr.combiner_repository_arn
  ]
}

################################################################################
# IAM Roles
################################################################################

module "iam" {
  source       = "./modules/iam"
  environment  = var.environment
  project_name = var.project_name
  region       = var.region
  tags         = local.tags

  # S3 bucket for IAM policies
  bucket_arn = module.s3.bucket_arn

  # Local testing role principals (optional)
  local_testing_upscale_role_principals = var.iam_local_testing_principals
}

################################################################################
# Batch Jobs
################################################################################

module "batch" {
  source       = "./modules/batch"
  environment  = var.environment
  project_name = var.project_name
  region       = var.region
  tags         = local.tags

  # Network
  security_group_id = module.vpc.batch_tasks_security_group_id
  subnets           = module.vpc.intra_subnets

  # ECR Repository URLs
  splitter_repository_url = module.ecr.splitter_repository_url
  combiner_repository_url = module.ecr.combiner_repository_url
  upscaler_repository_url = module.ecr.upscaler_repository_url
  image_tag               = var.batch_image_tag

  # IAM Roles from IAM module
  batch_service_role_arn      = module.iam.batch_service_role_arn
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  job_split_role_arn          = module.iam.job_split_role_arn
  job_combine_role_arn        = module.iam.job_combine_role_arn
  job_upscale_role_arn        = module.iam.job_upscale_role_arn
  job_upscale_runpod_role_arn = module.iam.job_upscale_runpod_role_arn

  # Compute
  fargate_max_vcpus  = var.batch_fargate_max_vcpus
  gpu_instance_types = var.batch_gpu_instance_types
  gpu_max_vcpus      = var.batch_gpu_max_vcpus
  gpu_min_vcpus      = var.batch_gpu_min_vcpus

  # Logging
  log_retention_days = var.batch_log_retention_days

  # Feature flags
  enable_split          = var.batch_enable_split
  enable_combine        = var.batch_enable_combine
  enable_upscale        = var.batch_enable_upscale
  enable_upscale_runpod = var.batch_enable_upscale_runpod
}

################################################################################
# DynamoDB
################################################################################

module "dynamodb" {
  source       = "./modules/dynamodb"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags
}

################################################################################
# EventBridge (RunPod Connection)
################################################################################

module "eventbridge" {
  source       = "./modules/eventbridge"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # RunPod Configuration
  runpod_api_key = var.runpod_api_key
}

################################################################################
# Step Functions
################################################################################

module "step_functions" {
  source       = "./modules/step_functions"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # S3 Bucket
  upscale_video_bucket_name = module.s3.bucket_id

  # Batch Job Configuration - Split
  upscale_video_split_job_queue_arn      = module.batch.split_job_queue_arn
  upscale_video_split_job_definition_arn = module.batch.split_job_definition_arn

  # Batch Job Configuration - Upscale
  upscale_video_upscale_job_queue_arn      = module.batch.upscale_job_queue_arn
  upscale_video_upscale_job_definition_arn = module.batch.upscale_job_definition_arn

  # Batch Job Configuration - Combine
  upscale_video_combine_job_queue_arn      = module.batch.combine_job_queue_arn
  upscale_video_combine_job_definition_arn = module.batch.combine_job_definition_arn

  # Lambda Configuration
  presign_s3_urls_lambda_function_arn   = module.lambda.presign_model_urls_lambda_function_arn
  submit_runpod_job_lambda_function_arn = module.lambda.submit_runpod_job_lambda_function_arn

  # RunPod Configuration
  runpod_base_api_endpoint = var.runpod_base_api_endpoint
  runpod_endpoint_id       = var.runpod_endpoint_id
  runpod_connection_arn    = module.eventbridge.runpod_connection_arn
  runpod_max_concurrency   = var.runpod_max_concurrency
}

################################################################################
# Lambda Functions
################################################################################

module "lambda" {
  source       = "./modules/lambda"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # S3 Bucket
  upscale_video_bucket_arn = module.s3.bucket_arn

  # DynamoDB
  runpod_callbacks_dynamodb_table_arn = module.dynamodb.runpod_callbacks_table_arn

  # API Gateway
  runpod_webhook_handler_api_gateway_execution_arn = module.api_gateway.runpod_webhook_handler_api_gateway_execution_arn

  # RunPod Configuration
  runpod_api_key_secret_arn = var.runpod_api_key_secret_arn
}

################################################################################
# API Gateway
################################################################################

module "api_gateway" {
  source       = "./modules/api_gateway"
  environment  = var.environment
  project_name = var.project_name
  tags         = local.tags

  # Lambda Configuration
  runpod_webhook_handler_lambda_arn = module.lambda.runpod_webhook_handler_lambda_function_arn
}
