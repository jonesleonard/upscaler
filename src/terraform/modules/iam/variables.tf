################################################################################
# Basic Variables
################################################################################

variable "bucket_arn" {
  description = "The ARN of the S3 bucket for IAM policies."
  type        = string
}

variable "environment" {
  description = "The environment for which the Terraform configuration is being applied (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "local_testing_upscale_role_principals" {
  description = "List of IAM principal ARNs (users/roles) that can assume the local testing role for generating presigned URLs."
  type        = list(string)
  default     = []
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "region" {
  description = "The AWS region where resources will be provisioned."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
