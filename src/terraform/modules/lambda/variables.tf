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
# Presign Upscale Video S3 URLs Lambda Configuration
################################################################################

variable "upscale_video_bucket_arn" {
  description = "The ARN of the Upscale Video S3 Bucket."
  type        = string
}
