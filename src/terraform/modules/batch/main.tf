################################################################################
# Batch - Split Job Module (Fargate)
################################################################################

module "split" {
  source = "./split"
  count  = var.enable_split ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  region       = var.region
  tags         = var.tags

  # Network
  security_group_id = var.security_group_id
  subnets           = var.subnets

  # Container
  repository_url = var.splitter_repository_url
  image_tag      = var.image_tag

  # Compute
  max_vcpus = var.fargate_max_vcpus

  # IAM
  ecs_task_execution_role_arn = var.ecs_task_execution_role_arn
  job_split_role_arn          = var.job_split_role_arn

  # Logging
  log_retention_days = var.log_retention_days
}

################################################################################
# Batch - Combine Job Module (Fargate)
################################################################################

module "combine" {
  source = "./combine"
  count  = var.enable_combine ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  region       = var.region
  tags         = var.tags

  # Network
  security_group_id = var.security_group_id
  subnets           = var.subnets

  # Container
  repository_url = var.combiner_repository_url
  image_tag      = var.image_tag

  # Compute
  max_vcpus = var.fargate_max_vcpus

  # IAM
  ecs_task_execution_role_arn = var.ecs_task_execution_role_arn
  job_combine_role_arn        = var.job_combine_role_arn

  # Logging
  log_retention_days = var.log_retention_days
}

################################################################################
# Batch - Upscale Job Module (EC2 with GPU)
################################################################################

module "upscale" {
  source = "./upscale"
  count  = var.enable_upscale ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  region       = var.region
  tags         = var.tags

  # Network
  security_group_id = var.security_group_id
  subnets           = var.subnets

  # Container
  repository_url = var.upscaler_repository_url
  image_tag      = var.image_tag

  # Compute
  instance_types = var.gpu_instance_types
  max_vcpus      = var.gpu_max_vcpus
  min_vcpus      = var.gpu_min_vcpus

  # IAM
  batch_service_role_arn = var.batch_service_role_arn
  job_upscale_role_arn   = var.job_upscale_role_arn

  # Logging
  log_retention_days = var.log_retention_days

  # Model configuration
  dit_model_s3_uri = var.dit_model_s3_uri
  vae_model_s3_uri = var.vae_model_s3_uri
  use_s5cmd        = var.use_s5cmd
  model_s3_bucket  = var.model_s3_bucket
}

################################################################################
# Batch - Upscale RunPod Job Module (Fargate - API calls)
################################################################################

module "upscale_runpod" {
  source = "./upscale_runpod"
  count  = var.enable_upscale_runpod ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  region       = var.region
  tags         = var.tags

  # Network
  security_group_id = var.security_group_id
  subnets           = var.subnets

  # Container - Reuses upscaler repository with different entrypoint/config
  repository_url = var.upscaler_repository_url
  image_tag      = var.image_tag

  # Compute
  max_vcpus = var.fargate_max_vcpus

  # IAM
  ecs_task_execution_role_arn = var.ecs_task_execution_role_arn
  job_upscale_runpod_role_arn = var.job_upscale_runpod_role_arn

  # Logging
  log_retention_days = var.log_retention_days
}
