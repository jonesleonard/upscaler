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
# Network Configuration
################################################################################

variable "security_group_id" {
  description = "The ID of the security group for Batch compute resources."
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for Batch compute resources."
  type        = list(string)
}

################################################################################
# ECR Repository URLs
################################################################################

variable "combiner_repository_url" {
  description = "The URL of the ECR repository for the combiner container image."
  type        = string
}

variable "splitter_repository_url" {
  description = "The URL of the ECR repository for the splitter container image."
  type        = string
}

variable "upscaler_repository_url" {
  description = "The URL of the ECR repository for the upscaler container image."
  type        = string
}

variable "image_tag" {
  description = "The tag of the container images to use for job definitions."
  type        = string
  default     = "latest"
}

################################################################################
# IAM Configuration
################################################################################

variable "batch_service_role_arn" {
  description = "The ARN of the Batch service role for EC2 compute environments."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role for Fargate compute environments."
  type        = string
}

variable "job_combine_role_arn" {
  description = "The ARN of the IAM role for the combine job."
  type        = string
}

variable "job_split_role_arn" {
  description = "The ARN of the IAM role for the split job."
  type        = string
}

variable "job_upscale_role_arn" {
  description = "The ARN of the IAM role for the upscale job."
  type        = string
}

variable "job_upscale_runpod_role_arn" {
  description = "The ARN of the IAM role for the upscale_runpod job."
  type        = string
}

################################################################################
# Compute Configuration
################################################################################

variable "fargate_max_vcpus" {
  description = "Maximum number of vCPUs for Fargate compute environments."
  type        = number
  default     = 16
}

variable "gpu_instance_types" {
  description = "List of EC2 instance types for GPU compute. Use 'g' or 'p' instance families for GPU workloads."
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge"]
}

variable "gpu_max_vcpus" {
  description = "Maximum number of vCPUs for GPU EC2 compute environments."
  type        = number
  default     = 32
}

variable "gpu_min_vcpus" {
  description = "Minimum number of vCPUs for GPU EC2 compute environments. Set to 0 to scale down completely."
  type        = number
  default     = 0
}

################################################################################
# Logging Configuration
################################################################################

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs for all Batch jobs."
  type        = number
  default     = 7
}

################################################################################
# Feature Flags
################################################################################

variable "enable_combine" {
  description = "Enable the combine Batch job module."
  type        = bool
  default     = true
}

variable "enable_split" {
  description = "Enable the split Batch job module."
  type        = bool
  default     = true
}

variable "enable_upscale" {
  description = "Enable the upscale (GPU EC2) Batch job module."
  type        = bool
  default     = true
}

variable "enable_upscale_runpod" {
  description = "Enable the upscale_runpod (Fargate API) Batch job module."
  type        = bool
  default     = false
}
