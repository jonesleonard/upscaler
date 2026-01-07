################################################################################
# API Gateway - RunPod Webhook Handler Outputs
################################################################################

output "runpod_webhook_handler_api_gateway_arn" {
  description = "The ARN of the RunPod Webhook Handler API Gateway."
  value       = module.runpod_webhook_handler_api_gateway.api_arn
}

output "runpod_webhook_handler_api_gateway_endpoint" {
  description = "The endpoint URL of the RunPod Webhook Handler API Gateway."
  value       = module.runpod_webhook_handler_api_gateway.api_endpoint
}

output "runpod_webhook_handler_api_gateway_execution_arn" {
  description = "The execution ARN of the RunPod Webhook Handler API Gateway."
  value       = module.runpod_webhook_handler_api_gateway.api_execution_arn
}

output "runpod_webhook_handler_api_gateway_id" {
  description = "The ID of the RunPod Webhook Handler API Gateway."
  value       = module.runpod_webhook_handler_api_gateway.api_id
}

output "runpod_webhook_handler_api_gateway_name" {
  description = "The name of the RunPod Webhook Handler API Gateway."
  value       = local.runpod_webhook_handler_api_gateway_name
}
