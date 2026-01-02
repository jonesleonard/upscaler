################################################################################
# Supporting Resources
################################################################################

data "aws_caller_identity" "current" {}

locals {
  # job role names
  job_split_role_name          = "job-split-role-${var.environment}"
  job_upscale_role_name        = "job-upscale-role-${var.environment}"
  job_combine_role_name        = "job-combine-role-${var.environment}"
  job_upscale_runpod_role_name = "job-upscale-runpod-role-${var.environment}"

  # batch role names
  batch_service_role_name      = "batch-service-role-${var.environment}"
  ecs_task_execution_role_name = "ecs-task-exec-${var.environment}"

  # lambda role names
  presign_urls_lambda_role_name = "lambda-presign-url-role-${var.environment}"

  # S3 bucket ownership condition to ensure the IAM role only accesses resources in the correct account
  s3_bucket_ownership_condition = [{
    test     = "StringEquals"
    variable = "s3:ResourceAccount"
    values   = [data.aws_caller_identity.current.account_id]
  }]

  # to receive a more informative 404 Not Found error if the object is indeed missing instead of the generic 403 Access Denied
  list_bucket_statement_ownership_condition = {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.bucket_arn]
    condition = local.s3_bucket_ownership_condition
  }

  # to receive a more informative 404 Not Found error if the object is indeed missing instead of the generic 403 Access Denied
  list_bucket_statement = {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.bucket_arn]
  }
}

################################################################################
# Job Split IAM Role
################################################################################

# Read from input/, write to runs/*/raw/ and manifest.json

module "job_split_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name                 = local.job_split_role_name
  create_inline_policy = true

  trust_policy_permissions = {
    ECSTasks = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  }

  inline_policy_permissions = {
    ListBucket = local.list_bucket_statement_ownership_condition,
    ReadInput = {
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "${var.bucket_arn}/input/*"
      ]
      condition = local.s3_bucket_ownership_condition
    },
    UpdateRawManifest = {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        "${var.bucket_arn}/runs/*/raw/*",
        "${var.bucket_arn}/runs/*/manifest.json"
      ]
      condition = local.s3_bucket_ownership_condition
    }
  }

  tags = merge({ Name = local.job_split_role_name, Component = "SPLIT" }, var.tags)
}

################################################################################
# Job Upscale IAM Role
################################################################################

# IAM role for job_upscale: Read from runs/*/raw/, write to runs/*/upscaled/

locals {
  inline_policy_permissions_upscale = {
    ListBucket = local.list_bucket_statement_ownership_condition,
    ReadRawModels = {
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "${var.bucket_arn}/runs/*/raw/*",
        "${var.bucket_arn}/models/*"
      ]
      condition = local.s3_bucket_ownership_condition
    },
    WriteUpscaled = {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        "${var.bucket_arn}/runs/*/upscaled/*"
      ]
      condition = local.s3_bucket_ownership_condition
    }
  }
}

module "job_upscale_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name                 = local.job_upscale_role_name
  create_inline_policy = true

  trust_policy_permissions = {
    ECSTasks = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  }

  inline_policy_permissions = local.inline_policy_permissions_upscale

  tags = merge({ Name = local.job_upscale_role_name, Component = "UPSCALE" }, var.tags)
}

################################################################################
# Job Upscale RunPod IAM Role
################################################################################

# IAM role for job_upscale_runpod: Read from runs/*/raw/, write to runs/*/upscaled/
# Similar to upscale but calls external RunPod API instead of local GPU processing

module "job_upscale_runpod_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name                 = local.job_upscale_runpod_role_name
  create_inline_policy = true

  trust_policy_permissions = {
    ECSTasks = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  }

  inline_policy_permissions = local.inline_policy_permissions_upscale

  tags = merge({ Name = local.job_upscale_runpod_role_name, Component = "UPSCALE_RUNPOD" }, var.tags)
}

################################################################################
# Job Combine IAM Role
################################################################################

# IAM role for job_combine: Read from runs/*/*, write to runs/*/final/

module "job_combine_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name                 = local.job_combine_role_name
  create_inline_policy = true

  trust_policy_permissions = {
    ECSTasks = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  }

  inline_policy_permissions = {
    ListBucket = local.list_bucket_statement_ownership_condition,
    ReadRuns = {
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "${var.bucket_arn}/runs/*/*"
      ]
      condition = local.s3_bucket_ownership_condition
    },
    WriteFinal = {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        "${var.bucket_arn}/runs/*/final/*"
      ]
      condition = local.s3_bucket_ownership_condition
    }
  }

  tags = merge({ Name = local.job_combine_role_name, Component = "COMBINE" }, var.tags)
}

################################################################################
# AWS Batch Service Role
################################################################################

module "batch_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name = local.batch_service_role_name

  trust_policy_permissions = {
    Batch = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["batch.amazonaws.com"]
      }]
    }
  }

  policies = {
    AWSBatchServiceRole = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
  }

  tags = merge({ Name = local.batch_service_role_name, Component = "BATCH_SERVICE" }, var.tags)
}

################################################################################
# ECS Tasks IAM Role
################################################################################

module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name = local.ecs_task_execution_role_name

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
      }]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = ["arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  }

  policies = {
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonECSTaskExecutionRolePolicy   = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  }

  tags = merge({ Name = local.ecs_task_execution_role_name, Component = "ECS_TASK_EXECUTION" }, var.tags)
}


################################################################################
# Lambda S3 Presign URLs IAM Role
################################################################################

module "presign_urls_lambda_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.2.3"

  name                 = local.presign_urls_lambda_role_name
  create_inline_policy = true

  trust_policy_permissions = {
    Lambda = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
    }
  }

  policies = {
    AWSLambdaBasicExecutionRole = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  }

  inline_policy_permissions = {
    ListBucket = local.list_bucket_statement,
    ReadInputsModels = {
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        "${var.bucket_arn}/input/*",
        "${var.bucket_arn}/runs/*",
        "${var.bucket_arn}/models/*"
      ]
      condition = local.s3_bucket_ownership_condition
    },
    WriteUpscaled = {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        "${var.bucket_arn}/runs/*/upscaled/*"
      ]
      condition = local.s3_bucket_ownership_condition
    }
  }

  tags = merge({ Name = local.presign_urls_lambda_role_name, Component = "LAMBDA_PRESIGN_URLS" }, var.tags)
}
