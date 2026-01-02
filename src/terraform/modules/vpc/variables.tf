################################################################################
# Basic Variables
################################################################################

variable "environment" {
  description = "The environment for which the Terraform configuration is being applied (e.g., dev, staging, prod). This is used to differentiate resources and state files for each environment."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

################################################################################
# VPC Configuration
################################################################################

variable "az_redundancy_level" {
  description = "The number of availability zones to use for redundancy. Must be at least 2 for high availability."
  type        = number
  default     = 2

  validation {
    condition     = var.az_redundancy_level >= 2 && var.az_redundancy_level <= 6
    error_message = "AZ redundancy level must be between 2 and 6."
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic monitoring and troubleshooting."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "Flow log retention must be a valid CloudWatch Logs retention period."
  }
}

variable "flow_log_traffic_type" {
  description = "The type of traffic to capture in VPC Flow Logs. Valid values: ACCEPT, REJECT, ALL."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "Flow log traffic type must be ACCEPT, REJECT, or ALL."
  }
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Must be a valid IPv4 CIDR block."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

################################################################################
# VPC Endpoint Configuration
################################################################################

variable "ecr_resource_arns" {
  description = "List of ECR repository ARNs to allow access through the VPC endpoint. If empty, all ECR repositories in the account are accessible."
  type        = list(string)
  default     = []
}
