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
# Upscale Video Configuration
################################################################################

variable "upscale_video_bucket_name" {
  description = "The name of the S3 bucket used for storing videos."
  type        = string
}

# Split Job Configuration
variable "upscale_video_split_job_queue_arn" {
  description = "The ARN of the Job queue used for split jobs."
  type        = string
}

variable "upscale_video_split_job_definition_arn" {
  description = "The ARN of the Job definition used for split jobs."
  type        = string
}

# Upscale Job Configuration
variable "upscale_video_upscale_job_queue_arn" {
  description = "The ARN of the Job queue used for upscale jobs."
  type        = string
}

variable "upscale_video_upscale_job_definition_arn" {
  description = "The ARN of the Job definition used for upscale jobs."
  type        = string
}

# Combine Job Configuration
variable "upscale_video_combine_job_queue_arn" {
  description = "The ARN of the Job queue used for combine jobs."
  type        = string
}

variable "upscale_video_combine_job_definition_arn" {
  description = "The ARN of the Job definition used for combine jobs."
  type        = string
}

################################################################################
# Lambda Configuration
################################################################################

variable "presign_s3_urls_lambda_function_arn" {
  description = "The ARN of the Lambda function used to presign S3 URIs."
  type        = string
}

variable "submit_runpod_job_lambda_function_arn" {
  description = "The ARN of the Lambda function used to submit RunPod jobs."
  type        = string
}

################################################################################
# RunPod Configuration
################################################################################

variable "runpod_base_api_endpoint" {
  description = "The base API endpoint for RunPod."
  type        = string
}

variable "runpod_endpoint_id" {
  description = "The ID of the RunPod endpoint."
  type        = string
}

variable "runpod_connection_arn" {
  description = "The ARN for the RunPod connection."
  type        = string
}

variable "runpod_max_concurrency" {
  description = "The maximum concurrency for the task that submits jobs to the RunPod Endpoint."
  type        = number
  default     = 10
}
