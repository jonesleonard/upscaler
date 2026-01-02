locals {
  ecr_splitter_repository_name = "${var.project_name}-splitter-${var.environment}-ecr"
  ecr_upscaler_repository_name = "${var.project_name}-upscaler-${var.environment}-ecr"
  ecr_combiner_repository_name = "${var.project_name}-combiner-${var.environment}-ecr"
}

################################################################################
# ECR Splitter Repository
################################################################################

module "ecr_splitter_repository" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.1.0"

  repository_name = local.ecr_splitter_repository_name

  repository_force_delete         = var.repository_force_delete
  repository_image_tag_mutability = var.repository_image_tag_mutability

  repository_encryption_type = var.repository_encryption_type
  repository_kms_key         = var.repository_kms_key

  repository_image_scan_on_push = var.repository_image_scan_on_push

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.tagged_image_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = var.tag_prefix_list,
          countType     = "imageCountMoreThan",
          countNumber   = var.tagged_image_count
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Expire untagged images older than ${var.untagged_image_days} days",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = var.untagged_image_days
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = merge({ Name = local.ecr_splitter_repository_name, Component = "SPLIT" }, var.tags)
}

################################################################################
# ECR Upscaler Repository
################################################################################

module "ecr_upscaler_repository" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.1.0"

  repository_name = local.ecr_upscaler_repository_name

  repository_force_delete         = var.repository_force_delete
  repository_image_tag_mutability = var.repository_image_tag_mutability

  repository_encryption_type = var.repository_encryption_type
  repository_kms_key         = var.repository_kms_key

  repository_image_scan_on_push = var.repository_image_scan_on_push

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.tagged_image_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = var.tag_prefix_list,
          countType     = "imageCountMoreThan",
          countNumber   = var.tagged_image_count
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Expire untagged images older than ${var.untagged_image_days} days",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = var.untagged_image_days
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = merge({ Name = local.ecr_upscaler_repository_name, Component = "UPSCALE" }, var.tags)
}

################################################################################
# ECR Combiner Repository
################################################################################

module "ecr_combiner_repository" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.1.0"

  repository_name = local.ecr_combiner_repository_name

  repository_force_delete         = var.repository_force_delete
  repository_image_tag_mutability = var.repository_image_tag_mutability

  repository_encryption_type = var.repository_encryption_type
  repository_kms_key         = var.repository_kms_key

  repository_image_scan_on_push = var.repository_image_scan_on_push

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.tagged_image_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = var.tag_prefix_list,
          countType     = "imageCountMoreThan",
          countNumber   = var.tagged_image_count
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Expire untagged images older than ${var.untagged_image_days} days",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = var.untagged_image_days
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = merge({ Name = local.ecr_combiner_repository_name, Component = "COMBINE" }, var.tags)
}
