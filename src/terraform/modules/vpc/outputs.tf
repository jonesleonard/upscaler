################################################################################
# VPC Outputs
################################################################################

output "azs" {
  description = "List of availability zones used by the VPC."
  value       = module.vpc.azs
}

output "intra_route_table_ids" {
  description = "List of IDs of intra route tables."
  value       = module.vpc.intra_route_table_ids
}

output "intra_subnet_arns" {
  description = "List of ARNs of intra subnets."
  value       = module.vpc.intra_subnets_cidr_blocks
}

output "intra_subnets" {
  description = "List of IDs of intra subnets."
  value       = module.vpc.intra_subnets
}

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

################################################################################
# Security Group Outputs
################################################################################

output "batch_tasks_security_group_id" {
  description = "The ID of the security group for Batch tasks."
  value       = aws_security_group.batch_tasks.id
}

output "vpc_endpoints_security_group_id" {
  description = "The ID of the security group for VPC endpoints."
  value       = module.vpc_endpoints.security_group_id
}

################################################################################
# VPC Endpoint Outputs
################################################################################

output "vpc_endpoints" {
  description = "Map of VPC endpoint IDs."
  value       = module.vpc_endpoints.endpoints
}
