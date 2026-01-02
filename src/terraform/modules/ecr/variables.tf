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
# ECR Repository Configuration
################################################################################

variable "repository_encryption_type" {
  description = "The encryption type to use for the repository. Valid values are AES256 or KMS."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.repository_encryption_type)
    error_message = "Repository encryption type must be either AES256 or KMS."
  }
}

variable "repository_force_delete" {
  description = "If true, will delete the repository even if it contains images. Useful for non-production environments."
  type        = bool
  default     = false
}

variable "repository_image_scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository."
  type        = bool
  default     = true
}

variable "repository_image_tag_mutability" {
  description = "The tag mutability setting for the repository. Must be one of: MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.repository_image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "repository_kms_key" {
  description = "The ARN of the KMS key to use when encryption_type is KMS. If not specified, uses the default AWS managed key for ECR."
  type        = string
  default     = null
}

################################################################################
# Lifecycle Policy Configuration
################################################################################

variable "tag_prefix_list" {
  description = "List of image tag prefixes on which to apply the lifecycle policy for tagged images."
  type        = list(string)
  default     = ["v"]
}

variable "tagged_image_count" {
  description = "Number of tagged images to keep before expiring older images."
  type        = number
  default     = 30

  validation {
    condition     = var.tagged_image_count > 0
    error_message = "Tagged image count must be greater than 0."
  }
}

variable "untagged_image_days" {
  description = "Number of days to keep untagged images before expiring them."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_days > 0
    error_message = "Untagged image days must be greater than 0."
  }
}
