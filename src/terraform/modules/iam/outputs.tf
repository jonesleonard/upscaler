################################################################################
# Batch Service Role
################################################################################

output "batch_service_role_arn" {
  description = "The ARN of the AWS Batch service role."
  value       = module.batch_service_role.arn
}

output "batch_service_role_name" {
  description = "The name of the AWS Batch service role."
  value       = module.batch_service_role.name
}

################################################################################
# ECS Task Execution Role
################################################################################

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = module.ecs_task_execution_role.arn
}

output "ecs_task_execution_role_name" {
  description = "The name of the ECS task execution role."
  value       = module.ecs_task_execution_role.name
}

################################################################################
# Job Split Role
################################################################################

output "job_split_role_arn" {
  description = "The ARN of the IAM role for the split job."
  value       = module.job_split_role.arn
}

output "job_split_role_name" {
  description = "The name of the split job IAM role."
  value       = module.job_split_role.name
}

################################################################################
# Job Upscale Role
################################################################################

output "job_upscale_role_arn" {
  description = "The ARN of the IAM role for the upscale job."
  value       = module.job_upscale_role.arn
}

output "job_upscale_role_name" {
  description = "The name of the upscale job IAM role."
  value       = module.job_upscale_role.name
}

################################################################################
# Job Combine Role
################################################################################

output "job_combine_role_arn" {
  description = "The ARN of the IAM role for the combine job."
  value       = module.job_combine_role.arn
}

output "job_combine_role_name" {
  description = "The name of the combine job IAM role."
  value       = module.job_combine_role.name
}

################################################################################
# Job Upscale RunPod Role
################################################################################

output "job_upscale_runpod_role_arn" {
  description = "The ARN of the IAM role for the upscale RunPod job."
  value       = module.job_upscale_runpod_role.arn
}

output "job_upscale_runpod_role_name" {
  description = "The name of the upscale RunPod job IAM role."
  value       = module.job_upscale_runpod_role.name
}

################################################################################
# Lambda Presign URLs Role
################################################################################

output "presign_urls_lambda_role_arn" {
  description = "The ARN of the Lambda role for generating presigned S3 URLs."
  value       = module.presign_urls_lambda_role.arn
}

output "presign_urls_lambda_role_name" {
  description = "The name of the Lambda presign URLs role."
  value       = module.presign_urls_lambda_role.name
}
