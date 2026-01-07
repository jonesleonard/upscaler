################################################################################
# Secrets Manager - RunPod API Key Outputs
################################################################################

output "runpod_api_key_secret_arn" {
  description = "The ARN of the RunPod API Key secret."
  value       = module.runpod_api_key_secret.secret_arn
}

output "runpod_api_key_secret_id" {
  description = "The ID of the RunPod API Key secret."
  value       = module.runpod_api_key_secret.secret_id
}

output "runpod_api_key_secret_name" {
  description = "The name of the RunPod API Key secret."
  value       = module.runpod_api_key_secret.secret_name
}
