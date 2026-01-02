################################################################################
# Main Bucket Outputs
################################################################################

output "bucket_arn" {
  description = "The ARN of the main S3 bucket."
  value       = module.s3_bucket.s3_bucket_arn
}

output "bucket_domain_name" {
  description = "The bucket domain name of the main S3 bucket."
  value       = module.s3_bucket.s3_bucket_bucket_domain_name
}

output "bucket_id" {
  description = "The name/ID of the main S3 bucket."
  value       = module.s3_bucket.s3_bucket_id
}

output "bucket_region" {
  description = "The AWS region the main S3 bucket resides in."
  value       = module.s3_bucket.s3_bucket_region
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the main S3 bucket."
  value       = module.s3_bucket.s3_bucket_bucket_regional_domain_name
}

################################################################################
# Logging Bucket Outputs
################################################################################

output "logging_bucket_arn" {
  description = "The ARN of the logging S3 bucket."
  value       = module.s3_logging_bucket.s3_bucket_arn
}

output "logging_bucket_id" {
  description = "The name/ID of the logging S3 bucket."
  value       = module.s3_logging_bucket.s3_bucket_id
}
