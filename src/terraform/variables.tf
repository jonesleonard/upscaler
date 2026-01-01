################################################################################
# Basic Variables
################################################################################

variable "aws_profile" {
  description = "The AWS CLI profile to use for authentication. This profile should be configured in your AWS credentials file."
  type        = string
}

variable "region" {
  description = "The AWS region where resources will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment for which the Terraform configuration is being applied (e.g., dev, staging, prod). This is used to differentiate resources and state files for each environment."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}