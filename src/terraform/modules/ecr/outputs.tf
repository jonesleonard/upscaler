################################################################################
# Splitter Repository Outputs
################################################################################

output "splitter_repository_arn" {
  description = "The ARN of the splitter ECR repository."
  value       = module.ecr_splitter_repository.repository_arn
}

output "splitter_repository_name" {
  description = "The name of the splitter ECR repository."
  value       = module.ecr_splitter_repository.repository_name
}

output "splitter_repository_registry_id" {
  description = "The registry ID where the splitter repository was created."
  value       = module.ecr_splitter_repository.repository_registry_id
}

output "splitter_repository_url" {
  description = "The URL of the splitter ECR repository."
  value       = module.ecr_splitter_repository.repository_url
}

################################################################################
# Upscaler Repository Outputs
################################################################################

output "upscaler_repository_arn" {
  description = "The ARN of the upscaler ECR repository."
  value       = module.ecr_upscaler_repository.repository_arn
}

output "upscaler_repository_name" {
  description = "The name of the upscaler ECR repository."
  value       = module.ecr_upscaler_repository.repository_name
}

output "upscaler_repository_registry_id" {
  description = "The registry ID where the upscaler repository was created."
  value       = module.ecr_upscaler_repository.repository_registry_id
}

output "upscaler_repository_url" {
  description = "The URL of the upscaler ECR repository."
  value       = module.ecr_upscaler_repository.repository_url
}

################################################################################
# Combiner Repository Outputs
################################################################################

output "combiner_repository_arn" {
  description = "The ARN of the combiner ECR repository."
  value       = module.ecr_combiner_repository.repository_arn
}

output "combiner_repository_name" {
  description = "The name of the combiner ECR repository."
  value       = module.ecr_combiner_repository.repository_name
}

output "combiner_repository_registry_id" {
  description = "The registry ID where the combiner repository was created."
  value       = module.ecr_combiner_repository.repository_registry_id
}

output "combiner_repository_url" {
  description = "The URL of the combiner ECR repository."
  value       = module.ecr_combiner_repository.repository_url
}
