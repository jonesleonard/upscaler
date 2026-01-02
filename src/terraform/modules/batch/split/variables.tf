################################################################################
# Basic Variables
################################################################################

variable "environment" {
  description = "The environment for which the Terraform configuration is being applied (e.g., dev, staging, prod)."
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
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

################################################################################
# Batch Compute Configuration
################################################################################

variable "component" {
  description = "The component name for tagging purposes."
  type        = string
  default     = "SPLIT"
}

variable "max_vcpus" {
  description = "Maximum number of vCPUs for the compute environment."
  type        = number
  default     = 16

  validation {
    condition     = var.max_vcpus >= 1 && var.max_vcpus <= 256
    error_message = "Max vCPUs must be between 1 and 256."
  }
}

variable "security_group_id" {
  description = "The ID of the security group for Batch compute resources."
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for Batch compute resources."
  type        = list(string)
}

################################################################################
# Container Configuration
################################################################################

variable "image_tag" {
  description = "The tag of the container image to use for the job definition."
  type        = string
  default     = "latest"
}

variable "repository_url" {
  description = "The URL of the ECR repository containing the container image."
  type        = string
  default     = null
}

variable "splitter_image" {
  description = "Fallback container image to use if repository_url is not provided."
  type        = string
  default     = null
}

# Note: Validation that at least one image source is provided is done in the module
# via a lifecycle precondition or by checking at runtime.

################################################################################
# Job Definition Configuration
################################################################################

variable "attempt_duration_seconds" {
  description = "The time duration in seconds after which AWS Batch terminates jobs. Minimum 60 seconds."
  type        = number
  default     = 1800

  validation {
    condition     = var.attempt_duration_seconds >= 60
    error_message = "Attempt duration must be at least 60 seconds."
  }
}

variable "ephemeral_storage" {
  description = "The amount of ephemeral storage (in GiB) to allocate for the container."
  type        = number
  default     = 21

  validation {
    condition     = var.ephemeral_storage >= 21 && var.ephemeral_storage <= 200
    error_message = "Ephemeral storage must be between 21 and 200 GiB."
  }
}

variable "memory" {
  description = "The amount of memory (in MiB) to allocate for the container."
  type        = string
  default     = "2048"
}

variable "retry_attempts" {
  description = "Number of times to retry a failed job."
  type        = number
  default     = 1

  validation {
    condition     = var.retry_attempts >= 1 && var.retry_attempts <= 10
    error_message = "Retry attempts must be between 1 and 10."
  }
}

variable "vcpu" {
  description = "The number of vCPUs to allocate for the container."
  type        = string
  default     = "1"
}

################################################################################
# IAM Configuration
################################################################################

variable "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  type        = string
}

variable "job_split_role_arn" {
  description = "The ARN of the IAM role for the split job."
  type        = string
}

################################################################################
# Logging Configuration
################################################################################

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention period."
  }
}
