################################################################################
# Resource Group Outputs
################################################################################

output "resource_group_arn" {
  description = "The ARN of the resource group"
  value       = module.resource_group.arn
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.resource_group.name
}
