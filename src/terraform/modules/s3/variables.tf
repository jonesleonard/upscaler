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
# Upscale Video S3 Bucket Configuration
################################################################################

# CORS Configuration
variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS configuration. Use [\"*\"] for development or specific domains for production."
  type        = list(string)
  default     = ["*"]
}

# Lifecycle Configuration
variable "abort_multipart_upload_days" {
  description = "Number of days after which incomplete multipart uploads are aborted."
  type        = number
  default     = 7
}

variable "final_files_glacier_transition_days" {
  description = "Number of days after which final files are transitioned to Glacier storage."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Number of days to retain access logs before expiration."
  type        = number
  default     = 365
}

variable "raw_files_expiration_days" {
  description = "Number of days after which raw files are deleted."
  type        = number
  default     = 7
}

variable "upscaled_files_expiration_days" {
  description = "Number of days after which upscaled files are deleted."
  type        = number
  default     = 14
}
