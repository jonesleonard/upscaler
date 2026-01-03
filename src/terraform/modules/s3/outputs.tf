################################################################################
# Main Bucket Outputs
################################################################################

output "bucket_arn" {
  description = "The ARN of the upscale video S3 bucket."
  value       = module.upscale_video_bucket.s3_bucket_arn
}

output "bucket_domain_name" {
  description = "The bucket domain name of the upscale video S3 bucket."
  value       = module.upscale_video_bucket.s3_bucket_bucket_domain_name
}

output "bucket_id" {
  description = "The name/ID of the upscale video S3 bucket."
  value       = module.upscale_video_bucket.s3_bucket_id
}

output "bucket_region" {
  description = "The AWS region the upscale video S3 bucket resides in."
  value       = module.upscale_video_bucket.s3_bucket_region
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the upscale video S3 bucket."
  value       = module.upscale_video_bucket.s3_bucket_bucket_regional_domain_name
}

################################################################################
# Logging Bucket Outputs
################################################################################

output "logging_bucket_arn" {
  description = "The ARN of the logging upscale video S3 bucket."
  value       = module.upscale_video_bucket_logging_bucket.s3_bucket_arn
}

output "logging_bucket_id" {
  description = "The name/ID of the logging upscale video S3 bucket."
  value       = module.upscale_video_bucket_logging_bucket.s3_bucket_id
}
