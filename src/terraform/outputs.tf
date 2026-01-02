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

output "ecr_combiner_repository_arn" {
  description = "The ARN of the combiner ECR repository."
  value       = module.ecr.combiner_repository_arn
}

output "ecr_combiner_repository_url" {
  description = "The URL of the combiner ECR repository."
  value       = module.ecr.combiner_repository_url
}

output "ecr_splitter_repository_arn" {
  description = "The ARN of the splitter ECR repository."
  value       = module.ecr.splitter_repository_arn
}

output "ecr_splitter_repository_url" {
  description = "The URL of the splitter ECR repository."
  value       = module.ecr.splitter_repository_url
}

output "ecr_upscaler_repository_arn" {
  description = "The ARN of the upscaler ECR repository."
  value       = module.ecr.upscaler_repository_arn
}

output "ecr_upscaler_repository_url" {
  description = "The URL of the upscaler ECR repository."
  value       = module.ecr.upscaler_repository_url
}
