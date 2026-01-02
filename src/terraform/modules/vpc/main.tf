data "aws_availability_zones" "available" {}

locals {
  azs                                      = slice(data.aws_availability_zones.available.names, 0, var.az_redundancy_level)
  batch_tasks_security_group_name          = "${var.project_name}-${var.environment}-batch-tasks-sg"
  vpc_cidr                                 = var.vpc_cidr
  vpc_endpoints_name                       = "${var.project_name}-${var.environment}-vpc-endpoints"
  vpc_endpoints_security_group_name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints-sg-"
  vpc_name                                 = "${var.project_name}-${var.environment}-vpc"
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

  name = local.vpc_name
  cidr = local.vpc_cidr

  azs = local.azs

  intra_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 20)]

  # Required for VPC endpoints with private DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable VPC Flow Logs for security monitoring and troubleshooting
  enable_flow_log                                 = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role             = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group            = var.enable_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_days
  flow_log_traffic_type                           = var.flow_log_traffic_type

  tags = merge({ Name = local.vpc_name, Component = "NETWORK" }, var.tags)
}

################################################################################
# VPC ENDPOINTS
################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.5.1"

  vpc_id = module.vpc.vpc_id

  # Security group
  create_security_group      = true
  security_group_name_prefix = local.vpc_endpoints_security_group_name_prefix
  security_group_description = "VPC endpoint security group for ${local.vpc_name} in ${var.environment} environment"
  security_group_rules = {
    ingress_https = {
      description              = "HTTPS from Batch tasks"
      source_security_group_id = aws_security_group.batch_tasks.id
    }
  }

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = concat(module.vpc.intra_route_table_ids, try(module.vpc.private_route_table_ids, []))
      tags            = merge({ Name = "${local.vpc_name}-s3-endpoint", Component = "NETWORK" }, var.tags)
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = module.vpc.intra_route_table_ids
      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      tags            = merge({ Name = "${local.vpc_name}-dynamodb-endpoint", Component = "NETWORK" }, var.tags)
    },
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
      subnet_ids          = concat(module.vpc.intra_subnets, try(module.vpc.private_subnets, []))
      tags                = merge({ Name = "${local.vpc_name}-ecs-endpoint", Component = "NETWORK" }, var.tags)
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = concat(module.vpc.intra_subnets, try(module.vpc.private_subnets, []))
      policy              = data.aws_iam_policy_document.ecr_endpoint_policy.json
      tags                = merge({ Name = "${local.vpc_name}-ecr-api-endpoint", Component = "NETWORK" }, var.tags)
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = concat(module.vpc.intra_subnets, try(module.vpc.private_subnets, []))
      policy              = data.aws_iam_policy_document.ecr_endpoint_policy.json
      tags                = merge({ Name = "${local.vpc_name}-ecr-dkr-endpoint", Component = "NETWORK" }, var.tags)
    },
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = concat(module.vpc.intra_subnets, try(module.vpc.private_subnets, []))
      tags                = merge({ Name = "${local.vpc_name}-logs-endpoint", Component = "NETWORK" }, var.tags)
    }
  }

  tags = merge({ Name = local.vpc_endpoints_name, Component = "NETWORK" }, var.tags)
}

################################################################################
# Supporting Resources
################################################################################

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"
      values   = [module.vpc.vpc_id]
    }
  }
}

data "aws_iam_policy_document" "ecr_endpoint_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = var.ecr_resource_arns

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpc"

      values = [module.vpc.vpc_id]
    }
  }
}

################################################################################
# Batch Tasks Security Group
################################################################################

resource "aws_security_group" "batch_tasks" {
  name   = local.batch_tasks_security_group_name
  vpc_id = module.vpc.vpc_id

  tags = merge({ Name = local.batch_tasks_security_group_name, Component = "NETWORK" }, var.tags)
}

# Allow HTTPS egress (safe in private subnets; traffic to AWS services will use VPC endpoints)
resource "aws_vpc_security_group_egress_rule" "batch_tasks_https_egress" {
  security_group_id = aws_security_group.batch_tasks.id

  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"

  tags = merge({ Name = "${local.batch_tasks_security_group_name}-https-egress", Component = "NETWORK" }, var.tags)
}

# Allow DNS to the VPC resolver
resource "aws_vpc_security_group_egress_rule" "batch_tasks_dns_egress_udp" {
  security_group_id = aws_security_group.batch_tasks.id
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "udp"

  tags = merge({ Name = "${local.batch_tasks_security_group_name}-dns-egress-udp", Component = "NETWORK" }, var.tags)
}

resource "aws_vpc_security_group_egress_rule" "batch_tasks_dns_egress_tcp" {
  security_group_id = aws_security_group.batch_tasks.id
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "tcp"

  tags = merge({ Name = "${local.batch_tasks_security_group_name}-dns-egress-tcp", Component = "NETWORK" }, var.tags)
}
