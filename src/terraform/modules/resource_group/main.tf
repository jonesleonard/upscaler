################################################################################
# Resource Group
################################################################################

locals {
  main_resource_group_name = "${var.project_name}-${var.environment}-rg"
}

resource "aws_resourcegroups_group" "project" {
  name        = local.main_resource_group_name
  description = "All resources for ${var.project_name} ${var.environment} environment"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = [var.project_name]
        },
        {
          Key    = "Environment"
          Values = [var.environment]
        }
      ]
    })
  }

  tags = merge({ Name = local.main_resource_group_name, Component = "GLOBAL" }, var.tags)
}
