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

output "presign_model_urls_lambda_role_arn" {
  description = "The ARN of the IAM role for the Presign Model URLs Lambda function."
  value       = module.presign_model_urls_lambda.lambda_role_arn
}

output "presign_model_urls_lambda_invoke_arn" {
  description = "The invoke ARN of the Presign Model URLs Lambda function."
  value       = module.presign_model_urls_lambda.lambda_function_invoke_arn
}
