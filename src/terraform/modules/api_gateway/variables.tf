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

variable "runpod_webhook_handler_lambda_invoke_arn" {
  description = "The invoke ARN of the RunPod Webhook Handler Lambda function (required for API Gateway integration)."
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS configuration. Use ['*'] for development or specific domains for production."
  type        = list(string)
  default     = ["*"]
}

variable "stage_name" {
  description = "The name of the API Gateway stage (e.g., 'prod', 'dev')."
  type        = string
  default     = "$default"
}

variable "enable_throttling" {
  description = "Enable throttling for the API Gateway."
  type        = bool
  default     = false
}

variable "throttle_burst_limit" {
  description = "The API throttling burst limit."
  type        = number
  default     = 5000
}

variable "throttle_rate_limit" {
  description = "The API throttling rate limit."
  type        = number
  default     = 10000
}
