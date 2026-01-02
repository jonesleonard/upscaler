################################################################################
# Split Job Outputs
################################################################################

output "split_job_definition_arn" {
  description = "The ARN of the split job definition."
  value       = var.enable_split ? module.split[0].job_definition_arn : null
}

output "split_job_definition_name" {
  description = "The name of the split job definition."
  value       = var.enable_split ? module.split[0].job_definition_name : null
}

output "split_job_queue_arn" {
  description = "The ARN of the split job queue."
  value       = var.enable_split ? module.split[0].job_queue_arn : null
}

output "split_job_queue_name" {
  description = "The name of the split job queue."
  value       = var.enable_split ? module.split[0].job_queue_name : null
}

output "split_log_group_name" {
  description = "The name of the split CloudWatch log group."
  value       = var.enable_split ? module.split[0].log_group_name : null
}

################################################################################
# Combine Job Outputs
################################################################################

output "combine_job_definition_arn" {
  description = "The ARN of the combine job definition."
  value       = var.enable_combine ? module.combine[0].job_definition_arn : null
}

output "combine_job_definition_name" {
  description = "The name of the combine job definition."
  value       = var.enable_combine ? module.combine[0].job_definition_name : null
}

output "combine_job_queue_arn" {
  description = "The ARN of the combine job queue."
  value       = var.enable_combine ? module.combine[0].job_queue_arn : null
}

output "combine_job_queue_name" {
  description = "The name of the combine job queue."
  value       = var.enable_combine ? module.combine[0].job_queue_name : null
}

output "combine_log_group_name" {
  description = "The name of the combine CloudWatch log group."
  value       = var.enable_combine ? module.combine[0].log_group_name : null
}

################################################################################
# Upscale Job Outputs
################################################################################

output "upscale_job_definition_arn" {
  description = "The ARN of the upscale job definition."
  value       = var.enable_upscale ? module.upscale[0].job_definition_arn : null
}

output "upscale_job_definition_name" {
  description = "The name of the upscale job definition."
  value       = var.enable_upscale ? module.upscale[0].job_definition_name : null
}

output "upscale_job_queue_arn" {
  description = "The ARN of the upscale job queue."
  value       = var.enable_upscale ? module.upscale[0].job_queue_arn : null
}

output "upscale_job_queue_name" {
  description = "The name of the upscale job queue."
  value       = var.enable_upscale ? module.upscale[0].job_queue_name : null
}

output "upscale_log_group_name" {
  description = "The name of the upscale CloudWatch log group."
  value       = var.enable_upscale ? module.upscale[0].log_group_name : null
}

################################################################################
# Upscale RunPod Job Outputs
################################################################################

output "upscale_runpod_job_definition_arn" {
  description = "The ARN of the upscale_runpod job definition."
  value       = var.enable_upscale_runpod ? module.upscale_runpod[0].job_definition_arn : null
}

output "upscale_runpod_job_definition_name" {
  description = "The name of the upscale_runpod job definition."
  value       = var.enable_upscale_runpod ? module.upscale_runpod[0].job_definition_name : null
}

output "upscale_runpod_job_queue_arn" {
  description = "The ARN of the upscale_runpod job queue."
  value       = var.enable_upscale_runpod ? module.upscale_runpod[0].job_queue_arn : null
}

output "upscale_runpod_job_queue_name" {
  description = "The name of the upscale_runpod job queue."
  value       = var.enable_upscale_runpod ? module.upscale_runpod[0].job_queue_name : null
}

output "upscale_runpod_log_group_name" {
  description = "The name of the upscale_runpod CloudWatch log group."
  value       = var.enable_upscale_runpod ? module.upscale_runpod[0].log_group_name : null
}
