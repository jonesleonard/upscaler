data "aws_caller_identity" "current" {}

locals {
  bucket_name         = "${var.project_name}-${var.environment}"
  logging_bucket_name = "${var.project_name}-${var.environment}-logs"
}

################################################################################
# S3 Main Bucket
################################################################################

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.9.1"

  bucket = local.bucket_name

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_deny_incorrect_encryption_headers = true
  attach_deny_insecure_transport_policy    = true
  attach_deny_unencrypted_object_uploads   = true
  attach_require_latest_tls_policy         = true

  expected_bucket_owner                  = data.aws_caller_identity.current.account_id
  transition_default_minimum_object_size = "varies_by_storage_class"

  # CORS configuration for presigned URL uploads
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "PUT", "POST"]
      allowed_origins = var.cors_allowed_origins
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  ]

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "raw-files-expiration"
      enabled = true

      filter = {
        prefix = "runs/"
        tags = {
          type = "raw"
        }
      }

      expiration = {
        days = var.raw_files_expiration_days
      }
    },
    {
      id      = "upscaled-files-expiration"
      enabled = true

      filter = {
        prefix = "runs/"
        tags = {
          type = "upscaled"
        }
      }

      expiration = {
        days = var.upscaled_files_expiration_days
      }
    },
    {
      id      = "final-files-transition"
      enabled = true

      filter = {
        prefix = "runs/"
        tags = {
          type = "final"
        }
      }

      transition = [
        {
          days          = var.final_files_glacier_transition_days
          storage_class = "GLACIER"
        }
      ]
    },
    {
      id      = "abort-multipart-uploads"
      enabled = true

      abort_incomplete_multipart_upload_days = var.abort_multipart_upload_days
    }
  ]

  logging = {
    target_bucket = module.s3_logging_bucket.s3_bucket_id
    target_prefix = "log/"
    target_object_key_format = {
      partitioned_prefix = {
        partition_date_source = "DeliveryTime"
      }
    }
  }

  tags = merge({ Name = local.bucket_name }, var.tags)
}

################################################################################
# S3 Logging Bucket
################################################################################

module "s3_logging_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.9.1"

  bucket = local.logging_bucket_name

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  attach_access_log_delivery_policy     = true
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  # Use ARN pattern to avoid cyclic dependency
  access_log_delivery_policy_source_accounts = [data.aws_caller_identity.current.account_id]
  access_log_delivery_policy_source_buckets  = ["arn:aws:s3:::${local.bucket_name}"]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  lifecycle_rule = [
    {
      id      = "log-expiration"
      enabled = true

      expiration = {
        days = var.log_retention_days
      }
    },
    {
      id      = "log-transition-to-glacier"
      enabled = true

      transition = [
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]

  tags = merge({ Name = local.logging_bucket_name }, var.tags)
}
