
locals {
  runpod_connection_name_bus = "${var.project_name}-${var.environment}-runpod-connection-bus"
  runpod_connection_name     = "${var.project_name}-${var.environment}-runpod-connection"
}

################################################################################
# RunPod Configuration
################################################################################

module "runpod_connection" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~> 4.2"

  bus_name = local.runpod_connection_name_bus

  create_connections      = true
  create_api_destinations = false

  connections = {
    "${local.runpod_connection_name}" = {
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
      Name      = local.runpod_connection_name_bus
      Component = "RUNPOD"
    },
    var.tags
  )
}
