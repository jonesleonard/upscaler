data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#################################################################################
# Lambda - Generate Presigned Model URLs
#################################################################################

locals {
  presign_model_urls_lambda_name = "${var.project_name}-${var.environment}-presigned-urls-lambda"
  # Construct the Step Function ARN pattern to avoid circular dependency
  upscale_video_state_machine_arn_pattern = "arn:aws:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.project_name}-${var.environment}-upscale-video-sfn"
  s3_bucket_ownership_condition = [{
    test     = "StringEquals"
    variable = "s3:ResourceAccount"
    values   = [data.aws_caller_identity.current.account_id]
  }]
}

module "presign_model_urls_lambda" {
  source = "terraform-aws-modules/lambda/aws"

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
