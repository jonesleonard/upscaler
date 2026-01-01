locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

################################################################################
# Resource Group
################################################################################

module "resource_group" {
  source       = "./modules/resource_group"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.tags
}
