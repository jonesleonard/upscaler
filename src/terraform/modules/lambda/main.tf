data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Construct the Step Function ARN pattern to avoid circular dependency
  upscale_video_state_machine_arn_pattern = "arn:aws:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.project_name}-${var.environment}-upscale-video-sfn"
  s3_bucket_ownership_condition = [{
    test     = "StringEquals"
    variable = "s3:ResourceAccount"
    values   = [data.aws_caller_identity.current.account_id]
  }]
}

#################################################################################
# Lambda - Generate Presigned Model URLs
#################################################################################

locals {
  presign_model_urls_lambda_name = "${var.project_name}-${var.environment}-presigned-urls-lambda"
}

module "presign_model_urls_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = local.presign_model_urls_lambda_name
  description   = "Lambda function to generate presigned URLs for S3 objects"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "${path.module}/../../../lambdas/presign_s3_urls"

  # Packaging configuration
  artifacts_dir = "${path.root}/lambda_builds"
  hash_extra    = "presign_s3_urls"

  publish = true

  attach_tracing_policy              = true
  attach_cloudwatch_logs_policy      = true
  attach_create_log_group_permission = true
  cloudwatch_logs_retention_in_days  = 7

  allowed_triggers = {
    StepFunctions = {
      principal  = "states.amazonaws.com"
      source_arn = local.upscale_video_state_machine_arn_pattern
    }
  }

  role_name = "${local.presign_model_urls_lambda_name}-role"
  role_path = "/lambda/${local.presign_model_urls_lambda_name}/"

  attach_policy_statements = true
  policy_statements = [
    {
      effect  = "Allow",
      actions = ["s3:GetObject"],
      resources = [
        "${var.upscale_video_bucket_arn}/input/*",
        "${var.upscale_video_bucket_arn}/runs/*",
        "${var.upscale_video_bucket_arn}/models/*"
      ],
      condition = local.s3_bucket_ownership_condition
    },
    {
      effect  = "Allow",
      actions = ["s3:PutObject"],
      resources = [
        "${var.upscale_video_bucket_arn}/runs/*/upscaled/*"
      ],
      condition = local.s3_bucket_ownership_condition
    }
  ]

  tags = merge(var.tags, {
    Name = local.presign_model_urls_lambda_name
  })
}

#################################################################################
# Lambda - RunPod Webhook Handler
#################################################################################

locals {
  runpod_webhook_handler_lambda_name = "${var.project_name}-${var.environment}-runpod-webhook-handler-lambda"
}

module "runpod_webhook_handler_lambda" {

  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = local.runpod_webhook_handler_lambda_name
  description   = "Lambda function to handle RunPod webhook callbacks"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "${path.module}/../../../lambdas/runpod_webhook_handler"

  environment_variables = {
    CALLBACK_TABLE_NAME = var.runpod_callbacks_table_name
  }

  # Packaging configuration
  artifacts_dir = "${path.root}/lambda_builds"
  hash_extra    = "runpod_webhook_handler"

  publish = true

  attach_tracing_policy              = true
  attach_cloudwatch_logs_policy      = true
  attach_create_log_group_permission = true
  cloudwatch_logs_retention_in_days  = 7

  allowed_triggers = {
    APIGatewayAny = {
      service    = "apigateway"
      source_arn = "${var.runpod_webhook_handler_api_gateway_execution_arn}/*/*"
    },
  }

  role_name = "${local.runpod_webhook_handler_lambda_name}-role"
  role_path = "/lambda/${local.runpod_webhook_handler_lambda_name}/"

  attach_policy_statements = true
  policy_statements = [
    {
      effect = "Allow",
      actions = [
        "states:SendTaskSuccess",
        "states:SendTaskFailure",
        "states:SendTaskHeartbeat"
      ],
      resources = [
        local.upscale_video_state_machine_arn_pattern
      ]
    },
    {
      effect = "Allow",
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      resources = [
        var.runpod_callbacks_dynamodb_table_arn
      ]
    }
  ]

  tags = merge(var.tags, {
    Name = local.runpod_webhook_handler_lambda_name
  })
}

#################################################################################
# Lambda - Submit RunPod Job
#################################################################################

locals {
  submit_runpod_job_lambda_name = "${var.project_name}-${var.environment}-submit-runpod-job-lambda"
}

module "submit_runpod_job_lambda" {

  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.2"

  function_name = local.submit_runpod_job_lambda_name
  description   = "Lambda function to submit RunPod jobs"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  source_path = "${path.module}/../../../lambdas/submit_runpod_job"

  environment_variables = {
    CALLBACK_TABLE_NAME        = var.runpod_callbacks_table_name
    WEBHOOK_BASE_URL           = var.runpod_webhook_base_url
    RUNPOD_API_KEY_SECRET_NAME = var.runpod_api_key_secret_name
  }

  # Packaging configuration
  artifacts_dir = "${path.root}/lambda_builds"
  hash_extra    = "submit_runpod_job"
  publish       = true

  attach_tracing_policy              = true
  attach_cloudwatch_logs_policy      = true
  attach_create_log_group_permission = true
  cloudwatch_logs_retention_in_days  = 7

  allowed_triggers = {
    StepFunctions = {
      principal  = "states.amazonaws.com"
      source_arn = local.upscale_video_state_machine_arn_pattern
    }
  }

  role_name = "${local.submit_runpod_job_lambda_name}-role"
  role_path = "/lambda/${local.submit_runpod_job_lambda_name}/"

  attach_policy_statements = true
  policy_statements = [
    {
      effect = "Allow",
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ],
      resources = [
        var.runpod_api_key_secret_arn
      ]
    },
    {
      effect = "Allow",
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      resources = [
        var.runpod_callbacks_dynamodb_table_arn
      ]
    }
  ]

  tags = merge(var.tags, {
    Name = local.submit_runpod_job_lambda_name
  })
}
