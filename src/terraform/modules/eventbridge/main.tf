
locals {
  runpod_connection_name = "${var.project_name}-${var.environment}-runpod-connection"
}

################################################################################
# RunPod Configuration
################################################################################

module "runpod_connection" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~> 4.2"

  bus_name = local.runpod_connection_name

  create_connections      = true
  create_api_destinations = false

  connections = {
    "${var.project_name}_${var.environment}_upscaler_runpod" = {
      authorization_type = "API_KEY"
      auth_parameters = {
        api_key = {
          key   = "Authorization"
          value = "Bearer ${var.runpod_api_key}"
        }
      }
    }
  }

  tags = merge(
    {
      Name      = local.runpod_connection_name
      Component = "RUNPOD"
    },
    var.tags
  )
}
