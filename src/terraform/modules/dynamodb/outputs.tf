################################################################################
# DynamoDB - RunPod Callbacks Table Outputs
################################################################################

output "runpod_callbacks_table_arn" {
  description = "The ARN of the RunPod Callbacks DynamoDB table."
  value       = module.dynamodb_table.dynamodb_table_arn
}

output "runpod_callbacks_table_id" {
  description = "The ID (name) of the RunPod Callbacks DynamoDB table."
  value       = module.dynamodb_table.dynamodb_table_id
}

output "runpod_callbacks_table_name" {
  description = "The name of the RunPod Callbacks DynamoDB table."
  value       = local.runpod_callbacks_table_name
}
