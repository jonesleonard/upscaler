################################################################################
# RunPod Connection Outputs
################################################################################

output "runpod_connection_arn" {
  description = "The ARN of the RunPod EventBridge connection."
  value       = module.runpod_connection.eventbridge_connection_arns[local.runpod_connection_name]
}

output "runpod_connection_name" {
  description = "The name of the RunPod EventBridge connection."
  value       = local.runpod_connection_name
}
