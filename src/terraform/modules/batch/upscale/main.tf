locals {
  job_definition_name = "${var.project_name}-${var.environment}-upscale-job"
  job_queue_name      = "${var.project_name}-${var.environment}-upscale-job-queue"
  log_group_name      = "/aws/batch/${var.project_name}-upscale-${var.environment}"
}

################################################################################
# Batch - Upscale Job (EC2 with GPU)
################################################################################

module "batch_upscale" {
  source  = "terraform-aws-modules/batch/aws"
  version = "3.0.3"

  create_service_iam_role             = false
  create_instance_iam_role            = true
  instance_iam_role_name              = "batch-upscale-gpu-${var.environment}"
  instance_iam_role_path              = "/batch/"
  instance_iam_role_description       = "IAM role for AWS Batch EC2 GPU instances"
  create_spot_fleet_iam_role          = true
  spot_fleet_iam_role_name            = "${var.project_name}-${var.environment}-batch-spot-fleet-role"
  spot_fleet_iam_role_use_name_prefix = false

  compute_environments = {
    ec2_gpu = {
      name_prefix = "${var.project_name}-${var.environment}-upscale-ec2-gpu-"

      compute_resources = {
        type = "EC2"

        allocation_strategy = "BEST_FIT_PROGRESSIVE"
        instance_types      = var.instance_types
        max_vcpus           = var.max_vcpus
        min_vcpus           = var.min_vcpus

        security_group_ids = [var.security_group_id]
        subnets            = var.subnets

        tags = merge(var.tags, {
          Name      = "${var.project_name}-${var.environment}-upscale-ec2-gpu"
          Component = var.component
        })
      }

      service_role = var.batch_service_role_arn
    }

    ec2_gpu_spot = {
      name_prefix = "${var.project_name}-${var.environment}-upscale-ec2-gpu-spot-"

      compute_resources = {
        type = "SPOT"

        allocation_strategy = "SPOT_CAPACITY_OPTIMIZED"
        instance_types      = var.instance_types
        max_vcpus           = var.max_vcpus
        min_vcpus           = var.min_vcpus

        security_group_ids = [var.security_group_id]
        subnets            = var.subnets

        tags = merge(var.tags, {
          Name      = "${var.project_name}-${var.environment}-upscale-ec2-gpu-spot"
          Component = var.component
        })
      }

      service_role = var.batch_service_role_arn
    }
  }

  # Job queues and scheduling policies
  job_queues = {
    upscale_queue = {
      name                     = local.job_queue_name
      state                    = "ENABLED"
      priority                 = 10
      create_scheduling_policy = false

      # Prefer Spot instances for cost optimization, fall back to on-demand
      compute_environment_order = {
        0 = {
          compute_environment_key = "ec2_gpu_spot"
        }
        1 = {
          compute_environment_key = "ec2_gpu"
        }
      }

      tags = merge(var.tags, {
        Name      = local.job_queue_name
        Component = var.component
      })
    }
  }

  job_definitions = {
    upscale = {
      name                  = local.job_definition_name
      platform_capabilities = ["EC2"]
      propagate_tags        = true

      container_properties = jsonencode({
        image   = var.repository_url != null ? "${var.repository_url}:${var.image_tag}" : var.upscaler_image
        command = []

        resourceRequirements = [
          { type = "VCPU", value = tostring(var.vcpus) },
          { type = "MEMORY", value = tostring(var.memory) },
          { type = "GPU", value = tostring(var.gpu_count) }
        ]

        jobRoleArn = var.job_upscale_role_arn

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.id
            awslogs-region        = var.region
            awslogs-stream-prefix = "upscale"
          }
        }
      })

      attempt_duration_seconds = var.attempt_duration_seconds
      retry_strategy           = { attempts = 2 }

      tags = merge(var.tags, {
        Name      = local.job_definition_name
        Component = var.component
      })
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-batch-upscale-${var.environment}"
    Component = var.component
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name      = local.log_group_name
    Component = var.component
  })
}
