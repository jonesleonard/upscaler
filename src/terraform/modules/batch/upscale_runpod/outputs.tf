################################################################################
# Compute Environment Outputs
################################################################################

output "compute_environment_arns" {
  description = "Map of compute environment ARNs."
  value       = module.batch_upscale_runpod.compute_environments
}

################################################################################
# Job Definition Outputs
################################################################################

output "job_definition_arn" {
  description = "The ARN of the upscale_runpod job definition."
  value       = module.batch_upscale_runpod.job_definitions["upscale_runpod"].arn
}

output "job_definition_name" {
  description = "The name of the upscale_runpod job definition."
  value       = local.job_definition_name
}

################################################################################
# Job Queue Outputs
################################################################################

output "job_queue_arn" {
  description = "The ARN of the upscale_runpod job queue."
  value       = module.batch_upscale_runpod.job_queues["upscale_runpod_queue"].arn
}

output "job_queue_name" {
  description = "The name of the upscale_runpod job queue."
  value       = local.job_queue_name
}

################################################################################
# CloudWatch Outputs
################################################################################

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.arn
}

output "log_group_name" {
  description = "The name of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.name
}
