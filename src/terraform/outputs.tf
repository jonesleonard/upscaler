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
