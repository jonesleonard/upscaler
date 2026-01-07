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
# API Gateway - RunPod Webhook Handler Configuration
################################################################################

variable "runpod_webhook_handler_lambda_arn" {
  description = "The ARN of the RunPod Webhook Handler Lambda."
  type        = string
}