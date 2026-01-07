################################################################################
# Presign Model URLs Lambda Outputs
################################################################################

output "presign_model_urls_lambda_function_arn" {
  description = "The ARN of the Presign Model URLs Lambda function."
  value       = module.presign_model_urls_lambda.lambda_function_arn
}

output "presign_model_urls_lambda_function_name" {
  description = "The name of the Presign Model URLs Lambda function."
  value       = module.presign_model_urls_lambda.lambda_function_name
}

output "presign_model_urls_lambda_invoke_arn" {
  description = "The invoke ARN of the Presign Model URLs Lambda function."
  value       = module.presign_model_urls_lambda.lambda_function_invoke_arn
}

output "presign_model_urls_lambda_role_arn" {
  description = "The ARN of the IAM role for the Presign Model URLs Lambda function."
  value       = module.presign_model_urls_lambda.lambda_role_arn
}

################################################################################
# RunPod Webhook Handler Lambda Outputs
################################################################################

output "runpod_webhook_handler_lambda_function_arn" {
  description = "The ARN of the RunPod Webhook Handler Lambda function."
  value       = module.runpod_webhook_handler_lambda.lambda_function_arn
}

output "runpod_webhook_handler_lambda_function_name" {
  description = "The name of the RunPod Webhook Handler Lambda function."
  value       = module.runpod_webhook_handler_lambda.lambda_function_name
}

output "runpod_webhook_handler_lambda_invoke_arn" {
  description = "The invoke ARN of the RunPod Webhook Handler Lambda function."
  value       = module.runpod_webhook_handler_lambda.lambda_function_invoke_arn
}

output "runpod_webhook_handler_lambda_role_arn" {
  description = "The ARN of the IAM role for the RunPod Webhook Handler Lambda function."
  value       = module.runpod_webhook_handler_lambda.lambda_role_arn
}

################################################################################
# Submit RunPod Job Lambda Outputs
################################################################################

output "submit_runpod_job_lambda_function_arn" {
  description = "The ARN of the Submit RunPod Job Lambda function."
  value       = module.submit_runpod_job_lambda.lambda_function_arn
}

output "submit_runpod_job_lambda_function_name" {
  description = "The name of the Submit RunPod Job Lambda function."
  value       = module.submit_runpod_job_lambda.lambda_function_name
}

output "submit_runpod_job_lambda_invoke_arn" {
  description = "The invoke ARN of the Submit RunPod Job Lambda function."
  value       = module.submit_runpod_job_lambda.lambda_function_invoke_arn
}

output "submit_runpod_job_lambda_role_arn" {
  description = "The ARN of the IAM role for the Submit RunPod Job Lambda function."
  value       = module.submit_runpod_job_lambda.lambda_role_arn
}
