locals {
  job_definition_name = "${var.project_name}-${var.environment}-split-job"
  job_queue_name      = "${var.project_name}-${var.environment}-split-job-queue"
  log_group_name      = "/aws/batch/${var.project_name}-split-${var.environment}"
}

################################################################################
# Batch - Split Job
################################################################################

module "batch_split" {
  source  = "terraform-aws-modules/batch/aws"
  version = "3.0.3"

  depends_on = [aws_cloudwatch_log_group.this]

  create_instance_iam_role = false
  create_service_iam_role  = false

  compute_environments = {
    fargate = {
      name_prefix = "${var.project_name}-${var.environment}-split-fargate-"

      compute_resources = {
        type      = "FARGATE"
        max_vcpus = var.max_vcpus

        security_group_ids = [var.security_group_id]
        subnets            = var.subnets
      }
    }

    fargate_spot = {
      name_prefix = "${var.project_name}-${var.environment}-split-fargate-spot-"

      compute_resources = {
        type      = "FARGATE_SPOT"
        max_vcpus = var.max_vcpus

        security_group_ids = [var.security_group_id]
        subnets            = var.subnets
      }
    }
  }

  # Job queues and scheduling policies
  job_queues = {
    split_queue = {
      name                     = local.job_queue_name
      state                    = "ENABLED"
      priority                 = 10
      create_scheduling_policy = false

      compute_environment_order = {
        0 = {
          compute_environment_key = "fargate_spot"
        }
        1 = {
          compute_environment_key = "fargate"
        }
      }

      tags = merge(var.tags, {
        Name      = local.job_queue_name
        Component = var.component
      })
    }
  }

  job_definitions = {
    split = {
      name                  = local.job_definition_name
      platform_capabilities = ["FARGATE"]
      propagate_tags        = true

      container_properties = jsonencode({
        image   = var.repository_url != null ? "${var.repository_url}:${var.image_tag}" : var.splitter_image
        command = []

        resourceRequirements = [
          { type = "VCPU", value = var.vcpu },
          { type = "MEMORY", value = var.memory }
        ]

        ephemeralStorage = { sizeInGiB = var.ephemeral_storage }

        executionRoleArn = var.ecs_task_execution_role_arn
        jobRoleArn       = var.job_split_role_arn

        # Environment variables for hybrid splitting mode
        environment = [
          {
            name  = "USE_STREAM_COPY"
            value = "false" # Default to re-encode for precise boundaries
          },
          {
            name  = "RETRY_WITH_REENCODE"
            value = "true" # Enable hybrid mode: try stream copy first, fallback to re-encode
          },
          {
            name  = "V_CRF"
            value = "18" # High quality CRF for re-encoding
          }
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.id
            awslogs-region        = var.region
            awslogs-stream-prefix = "split"
          }
        }
      })

      attempt_duration_seconds = var.attempt_duration_seconds
      retry_strategy           = { attempts = var.retry_attempts }

      tags = merge(var.tags, {
        Name      = local.job_definition_name
        Component = var.component
      })
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-batch-split-${var.environment}"
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
