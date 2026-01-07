#################################################################################
# API Gateway - RunPod Webhook Handler
#################################################################################

locals {
  runpod_webhook_handler_api_gateway_name = "${var.project_name}-${var.environment}-api-gateway"
}

module "runpod_webhook_handler_api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "6.0.0"

  name          = local.runpod_webhook_handler_api_gateway_name
  description   = "API Gateway for ${var.project_name} in ${var.environment} environment"
  protocol_type = "HTTP"

  create_domain_name = false

  # Stage configuration
  stage_name = var.environment

  # CORS Configuration
  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = var.cors_allowed_origins
  }

  # Access logs
  stage_access_log_settings = {
    create_log_group            = true
    log_group_retention_in_days = 7
    format = jsonencode({
      context = {
        domainName              = "$context.domainName"
        integrationErrorMessage = "$context.integrationErrorMessage"
        protocol                = "$context.protocol"
        requestId               = "$context.requestId"
        requestTime             = "$context.requestTime"
        responseLength          = "$context.responseLength"
        routeKey                = "$context.routeKey"
        stage                   = "$context.stage"
        status                  = "$context.status"
        error = {
          message      = "$context.error.message"
          responseType = "$context.error.responseType"
        }
        identity = {
          sourceIP = "$context.identity.sourceIp"
        }
        integration = {
          error             = "$context.integration.error"
          integrationStatus = "$context.integration.integrationStatus"
        }
      }
    })
  }

  # Routes and Integration(s)
  routes = {
    "POST /runpod/webhook/{callback_token}" = {
      integration = {
        description            = "Integration for RunPod Webhook Handler Lambda"
        type                   = "AWS_PROXY"
        uri                    = var.runpod_webhook_handler_lambda_invoke_arn
        payload_format_version = "2.0"
        throttling_rate_limit  = var.throttle_rate_limit
        throttling_burst_limit = var.throttle_burst_limit
      }
    }
  }

  tags = merge(var.tags, {
    Name = local.runpod_webhook_handler_api_gateway_name
  })
}
