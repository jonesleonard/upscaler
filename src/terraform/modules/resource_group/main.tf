################################################################################
# Resource Group
################################################################################

resource "aws_resourcegroups_group" "project" {
  name        = "${var.project_name}-${var.environment}"
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

  tags = var.tags
}
