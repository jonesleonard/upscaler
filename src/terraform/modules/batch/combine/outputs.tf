################################################################################
# Compute Environment Outputs
################################################################################

output "compute_environment_arns" {
  description = "Map of compute environment ARNs."
  value       = module.batch_combine.compute_environments
}

################################################################################
# Job Definition Outputs
################################################################################

output "job_definition_arn" {
  description = "The ARN of the combine job definition."
  value       = module.batch_combine.job_definitions["combine"].arn
}

output "job_definition_name" {
  description = "The name of the combine job definition."
  value       = local.job_definition_name
}

################################################################################
# Job Queue Outputs
################################################################################

output "job_queue_arn" {
  description = "The ARN of the combine job queue."
  value       = module.batch_combine.job_queues["combine_queue"].arn
}

output "job_queue_name" {
  description = "The name of the combine job queue."
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
