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
