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
# Lambda - Shared Configuration
################################################################################

variable "runpod_callbacks_table_name" {
  description = "The name of the DynamoDB table used for storing RunPod callback information."
  type        = string
}

variable "runpod_callbacks_dynamodb_table_arn" {
  description = "The ARN of the RunPod Callbacks DynamoDB Table."
  type        = string
}

################################################################################
# Lambda - Presign Upscale Video S3 URLs Configuration
################################################################################

variable "upscale_video_bucket_arn" {
  description = "The ARN of the Upscale Video S3 Bucket."
  type        = string
}

################################################################################
# Lambda - RunPod Webhook Handler Configuration
################################################################################

variable "runpod_webhook_handler_api_gateway_execution_arn" {
  description = "The API Gateway Execution ARN of the API Gateway that manages the RunPod API connections"
  type        = string
}

################################################################################
# Lambda - Submit RunPod Job Configuration
################################################################################

variable "runpod_api_key_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing RunPod API credentials."
  type        = string
  sensitive   = true
}

variable "runpod_webhook_base_url" {
  description = "The base URL for the RunPod webhook handler API Gateway."
  type        = string
}

variable "runpod_api_key_secret_name" {
  description = "The name of the Secrets Manager secret containing RunPod API credentials."
  type        = string
  sensitive   = true
}
