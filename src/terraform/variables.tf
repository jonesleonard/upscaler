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

################################################################################
# VPC Configuration
################################################################################

variable "vpc_az_redundancy_level" {
  description = "The number of availability zones to use for VPC redundancy. Must be at least 2 for high availability."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Must be a valid IPv4 CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_enable_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic monitoring and troubleshooting."
  type        = bool
  default     = true
}

variable "vpc_flow_log_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch."
  type        = number
  default     = 30
}

variable "vpc_flow_log_traffic_type" {
  description = "The type of traffic to capture in VPC Flow Logs. Valid values: ACCEPT, REJECT, ALL."
  type        = string
  default     = "ALL"
}

################################################################################
# IAM Configuration
################################################################################

variable "iam_local_testing_principals" {
  description = "List of IAM principal ARNs (users/roles) that can assume the local testing role for generating presigned URLs."
  type        = list(string)
  default     = []
}

################################################################################
# Batch Configuration
################################################################################

variable "batch_enable_combine" {
  description = "Enable the combine Batch job module."
  type        = bool
  default     = true
}

variable "batch_enable_split" {
  description = "Enable the split Batch job module."
  type        = bool
  default     = true
}

variable "batch_enable_upscale" {
  description = "Enable the upscale (GPU EC2) Batch job module."
  type        = bool
  default     = true
}

variable "batch_enable_upscale_runpod" {
  description = "Enable the upscale_runpod (Fargate API) Batch job module."
  type        = bool
  default     = false
}

variable "batch_fargate_max_vcpus" {
  description = "Maximum number of vCPUs for Fargate compute environments."
  type        = number
  default     = 16
}

variable "batch_gpu_instance_types" {
  description = "List of EC2 instance types for GPU compute."
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge"]
}

variable "batch_gpu_max_vcpus" {
  description = "Maximum number of vCPUs for GPU EC2 compute environments."
  type        = number
  default     = 32
}

variable "batch_gpu_min_vcpus" {
  description = "Minimum number of vCPUs for GPU EC2 compute environments."
  type        = number
  default     = 0
}

variable "batch_image_tag" {
  description = "The tag of the container images to use for Batch job definitions."
  type        = string
  default     = "latest"
}

variable "batch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs for Batch jobs."
  type        = number
  default     = 7
}

################################################################################
# RunPod Configuration
################################################################################

variable "runpod_api_key" {
  description = "The API Key used to authenticate with RunPod."
  type        = string
  sensitive   = true
  default     = ""
}

variable "runpod_api_key_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the RunPod API key. Required for the submit_runpod_job Lambda."
  type        = string
  sensitive   = true
  default     = ""
}

variable "runpod_base_api_endpoint" {
  description = "The base API endpoint for RunPod (e.g., https://api.runpod.ai/v2)."
  type        = string
  default     = "https://api.runpod.ai/v2"
}

variable "runpod_endpoint_id" {
  description = "The ID of the RunPod serverless endpoint."
  type        = string
  default     = ""
}

variable "runpod_max_concurrency" {
  description = "The maximum concurrency for parallel RunPod upscale tasks."
  type        = number
  default     = 10
}
