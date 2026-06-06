//*******************************************
// ECS TASK DEFINITION
//*******************************************

resource "aws_ecs_task_definition" "moodle" {
  family                   = "${var.client_name}-moodle"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "moodle"
      image = var.moodle_image
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      # Use environment variables directly (no Secrets Manager)
      environment = [
        {
          name  = "MOODLE_DATABASE_TYPE"
          value = "mysqli"
        },
        {
          name  = "MOODLE_DATABASE_HOST"
          value = aws_db_instance.moodle.address
        },
        {
          name  = "MOODLE_DATABASE_PORT_NUMBER"
          value = tostring(var.db_port)
        },
        {
          name  = "MOODLE_DATABASE_NAME"
          value = var.db_name
        },
        {
          name  = "MOODLE_DATABASE_USER"
          value = var.db_master_username
        },
        {
          name  = "MOODLE_DATABASE_PASSWORD"
          value = var.db_master_password
        },
        {
          name  = "MOODLE_USERNAME"
          value = var.moodle_admin_user
        },
        {
          name  = "MOODLE_PASSWORD"
          value = var.moodle_admin_password
        },
        {
          name  = "MOODLE_EMAIL"
          value = var.moodle_admin_email
        },
        {
          name  = "MOODLE_SITE_NAME"
          value = var.moodle_site_name
        },
        {
          name  = "MOODLE_URL"
          value = "https://${var.production_url}"
        },
        {
          name  = "MOODLE_SKIP_BOOTSTRAP"
          value = "no"
        },
        {
          name  = "BITNAMI_DEBUG"
          value = "true"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.moodle.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "moodle"
        }
      }
    }
  ])

  tags = {
    Name = "${var.client_name}-moodle-task-def"
  }
}

# CloudWatch log group for Moodle
resource "aws_cloudwatch_log_group" "moodle" {
  name              = "/ecs/${var.client_name}-moodle"
  retention_in_days = var.retention_days

  tags = {
    Name = "${var.client_name}-moodle-logs"
  }
}
