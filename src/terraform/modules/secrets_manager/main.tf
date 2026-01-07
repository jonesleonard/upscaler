data "aws_caller_identity" "current" {}

#################################################################################
# Secrets Manager - RunPod API Key
#################################################################################

locals {
  runpod_api_key_secret = "${var.project_name}-${var.environment}-runpod-api-key-secret"
}

module "runpod_api_key_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.0.1"

  # Secret
  name_prefix             = local.runpod_api_key_secret
  description             = "Secret for RunPod API Key used by Submit RunPod Job Lambda"
  recovery_window_in_days = 30

  # Policy
  create_policy       = true
  block_public_policy = true
  policy_statements = {
    read = {
      sid = "AllowAccountRead"
      principals = [{
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }]
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ]
      resources = ["*"]
    }
  }

  tags = merge(var.tags, {
    Name = local.runpod_api_key_secret
  })
}
