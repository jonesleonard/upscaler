
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  upscale_video_step_function_name = "${var.project_name}-${var.environment}-upscale-video-sfn"
  runpod_connection_statements = {
    runpod_submit = {
      effect    = "Allow",
      actions   = ["states:InvokeHTTPEndpoint"],
      resources = ["arn:aws:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.upscale_video_step_function_name}"],
      conditions = {
        StringEquals = {
          "states:HTTPMethod" = "POST"
        }
        StringLike = {
          "states:HttpEndpoint" = "${var.runpod_base_api_endpoint}/${var.runpod_endpoint_id}/run"
        }
      }
    }
    runpod_status = {
      effect    = "Allow",
      actions   = ["states:InvokeHTTPEndpoint"],
      resources = ["arn:aws:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${local.upscale_video_step_function_name}"],
      conditions = {
        StringEquals = {
          "states:HTTPMethod" = "GET"
        }
        StringLike = {
          "states:HttpEndpoint" = "${var.runpod_base_api_endpoint}/${var.runpod_endpoint_id}/status/*"
        }
      }
    }
    use_runpod_connection = {
      effect    = "Allow",
      actions   = ["events:RetrieveConnectionCredentials"],
      resources = [var.runpod_connection_arn],
    }
    read_runpod_connection_secret = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      resources = ["arn:aws:secretsmanager:*:*:secret:events!connection/*"],
    }
  }
}

################################################################################  
# State Machine: Upscale Videos
################################################################################

module "upscale_video_state_machine" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "5.0.2"

  name = local.upscale_video_step_function_name

  definition = templatefile("${path.module}/definitions/upscale_video.tftpl", {
    # General Configuration
    BUCKET_NAME = var.upscale_video_bucket_name

    # AWS Batch Configuration
    SPLIT_JOB_QUEUE_ARN        = var.upscale_video_split_job_queue_arn
    SPLIT_JOB_DEFINITION_ARN   = var.upscale_video_split_job_definition_arn
    UPSCALE_JOB_QUEUE_ARN      = var.upscale_video_upscale_job_queue_arn
    UPSCALE_JOB_DEFINITION_ARN = var.upscale_video_upscale_job_definition_arn
    COMBINE_JOB_QUEUE_ARN      = var.upscale_video_combine_job_queue_arn
    COMBINE_JOB_DEFINITION_ARN = var.upscale_video_combine_job_definition_arn

    # Lambda Functions
    PRESIGN_SEGMENT_LAMBDA_ARN   = var.presign_s3_urls_lambda_function_arn
    SUBMIT_RUNPOD_JOB_LAMBDA_ARN = var.submit_runpod_job_lambda_function_arn

    # RunPod Configuration
    RUNPOD_CONNECTION_ARN         = var.runpod_connection_arn
    RUNPOD_RUN_ENDPOINT           = "${var.runpod_base_api_endpoint}/${var.runpod_endpoint_id}/run"
    RUNPOD_STATUS_ENDPOINT_PREFIX = "${var.runpod_base_api_endpoint}/${var.runpod_endpoint_id}/status"
    RUNPOD_MAX_CONCURRENCY        = var.runpod_max_concurrency
  })

  service_integrations = {
    xray = {
      xray = true
    }

    batch_Sync = {
      batch  = true
      events = true
    }

    lambda = {
      lambda = [
        var.presign_s3_urls_lambda_function_arn,
        var.submit_runpod_job_lambda_function_arn
      ]
    }
  }

  attach_policy_statements = true
  policy_statements = merge(local.runpod_connection_statements, {
    # direct AWS SDK calls within the Step Function definition requires the Step Functions execution role to have S3 read access
    s3_read = {
      effect    = "Allow",
      actions   = ["s3:HeadObject", "s3:GetObject"],
      resources = ["arn:aws:s3:::${var.upscale_video_bucket_name}/*"]
    }
  })

  type = "STANDARD"

  tags = merge(var.tags, {
    Name      = local.upscale_video_step_function_name,
    Component = "GLOBAL"
  })
}
