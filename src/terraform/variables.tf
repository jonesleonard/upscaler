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

variable "region" {
  description = "The AWS region where resources will be provisioned."
  type        = string
  default     = "us-east-1"
}

################################################################################
# S3 Configuration
################################################################################

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS configuration on S3. Use [\"*\"] for development or specific domains for production."
  type        = list(string)
  default     = ["*"]
}

variable "final_files_glacier_transition_days" {
  description = "Number of days after which final files are transitioned to Glacier storage."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Number of days to retain S3 access logs before expiration."
  type        = number
  default     = 365
}

variable "raw_files_expiration_days" {
  description = "Number of days after which raw files are deleted from S3."
  type        = number
  default     = 7
}

variable "upscaled_files_expiration_days" {
  description = "Number of days after which upscaled files are deleted from S3."
  type        = number
  default     = 14
}

################################################################################
# ECR Configuration
################################################################################

variable "ecr_repository_encryption_type" {
  description = "The encryption type to use for ECR repositories. Valid values are AES256 or KMS."
  type        = string
  default     = "AES256"
}

variable "ecr_repository_force_delete" {
  description = "If true, will delete ECR repositories even if they contain images. Useful for non-production environments."
  type        = bool
  default     = false
}

variable "ecr_repository_image_scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to ECR repositories."
  type        = bool
  default     = true
}

variable "ecr_repository_image_tag_mutability" {
  description = "The tag mutability setting for ECR repositories. Must be one of: MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"
}

variable "ecr_repository_kms_key" {
  description = "The ARN of the KMS key to use when encryption_type is KMS. If not specified, uses the default AWS managed key for ECR."
  type        = string
  default     = null
}

variable "ecr_tag_prefix_list" {
  description = "List of image tag prefixes on which to apply the lifecycle policy for tagged images in ECR."
  type        = list(string)
  default     = ["v"]
}

variable "ecr_tagged_image_count" {
  description = "Number of tagged images to keep in ECR before expiring older images."
  type        = number
  default     = 30
}

variable "ecr_untagged_image_days" {
  description = "Number of days to keep untagged images in ECR before expiring them."
  type        = number
  default     = 7
}
