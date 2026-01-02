################################################################################
# Batch Service Role
################################################################################

output "batch_service_role_arn" {
  description = "The ARN of the AWS Batch service role."
  value       = module.batch_service_role.iam_role_arn
}

output "batch_service_role_name" {
  description = "The name of the AWS Batch service role."
  value       = module.batch_service_role.iam_role_name
}

################################################################################
# ECS Instance Role (for EC2 compute environments)
################################################################################

output "ecs_instance_role_arn" {
  description = "The ARN of the ECS instance role for EC2 compute environments."
  value       = module.ecs_instance_role.iam_role_arn
}

output "ecs_instance_role_name" {
  description = "The name of the ECS instance role."
  value       = module.ecs_instance_role.iam_role_name
}

################################################################################
# ECS Task Execution Role
################################################################################

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = module.ecs_task_execution_role.iam_role_arn
}

output "ecs_task_execution_role_name" {
  description = "The name of the ECS task execution role."
  value       = module.ecs_task_execution_role.iam_role_name
}

################################################################################
# Job Split Role
################################################################################

output "job_split_role_arn" {
  description = "The ARN of the IAM role for the split job."
  value       = module.job_split_role.iam_role_arn
}

output "job_split_role_name" {
  description = "The name of the split job IAM role."
  value       = module.job_split_role.iam_role_name
}

################################################################################
# Job Upscale Role
################################################################################

output "job_upscale_role_arn" {
  description = "The ARN of the IAM role for the upscale job."
  value       = module.job_upscale_role.iam_role_arn
}

output "job_upscale_role_name" {
  description = "The name of the upscale job IAM role."
  value       = module.job_upscale_role.iam_role_name
}

################################################################################
# Job Combine Role
################################################################################

output "job_combine_role_arn" {
  description = "The ARN of the IAM role for the combine job."
  value       = module.job_combine_role.iam_role_arn
}

output "job_combine_role_name" {
  description = "The name of the combine job IAM role."
  value       = module.job_combine_role.iam_role_name
}

################################################################################
# Job Upscale RunPod Role
################################################################################

output "job_upscale_runpod_role_arn" {
  description = "The ARN of the IAM role for the upscale RunPod job."
  value       = module.job_upscale_runpod_role.iam_role_arn
}

output "job_upscale_runpod_role_name" {
  description = "The name of the upscale RunPod job IAM role."
  value       = module.job_upscale_runpod_role.iam_role_name
}

################################################################################
# Local Testing Role (optional)
################################################################################

output "local_testing_upscale_role_arn" {
  description = "The ARN of the local testing role for generating presigned URLs (if created)."
  value       = length(module.local_testing_upscale_role) > 0 ? module.local_testing_upscale_role[0].iam_role_arn : null
}

output "local_testing_upscale_role_name" {
  description = "The name of the local testing role (if created)."
  value       = length(module.local_testing_upscale_role) > 0 ? module.local_testing_upscale_role[0].iam_role_name : null
}

################################################################################
# Lambda Presign URLs Role
################################################################################

output "presign_urls_lambda_role_arn" {
  description = "The ARN of the Lambda role for generating presigned S3 URLs."
  value       = module.presign_urls_lambda_role.iam_role_arn
}

output "presign_urls_lambda_role_name" {
  description = "The name of the Lambda presign URLs role."
  value       = module.presign_urls_lambda_role.iam_role_name
}
