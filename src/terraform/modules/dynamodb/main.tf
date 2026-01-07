#################################################################################
# DynamoDB - Table for RunPod Callbacks
#################################################################################

locals {
  runpod_callbacks_table_name = "${var.project_name}-${var.environment}-runpod-callbacks-dynamodb"
}

module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "5.4.0"

  name     = local.runpod_callbacks_table_name
  hash_key = "callback_token"

  ttl_enabled        = true
  ttl_attribute_name = "expires_at"

  attributes = [
    {
      name = "callback_token"
      type = "S"
    }
  ]

  tags = merge(var.tags, {
    Name = local.runpod_callbacks_table_name
  })
}
