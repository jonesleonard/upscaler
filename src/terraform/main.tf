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
