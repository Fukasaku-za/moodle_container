//*******************************************
// ECS — Cluster, Task Definition & Service
//*******************************************

resource "aws_ecs_cluster" "moodle" {
  name = "${var.client_name}-moodle"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.client_name}_moodle_cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "moodle" {
  cluster_name       = aws_ecs_cluster.moodle.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

// CloudWatch log group for container logs
resource "aws_cloudwatch_log_group" "moodle_app" {
  name              = "/ecs/${var.client_name}/moodle"
  retention_in_days = var.retention_days
}

// Task definition
resource "aws_ecs_task_definition" "moodle" {
  family                   = "${var.client_name}-moodle"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  // EFS volumes — one for app files, one for moodledata
  volume {
    name = "moodle-app"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.moodle.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.moodle_app.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "moodledata"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.moodle.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2998
      authorization_config {
        access_point_id = aws_efs_access_point.moodledata.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "moodle"
      image     = var.moodle_image
      essential = true
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      // Bitnami Moodle environment variables
      // Secrets are injected from Secrets Manager — no plaintext in task def
      environment = [
        { name = "MOODLE_DATABASE_TYPE",        value = "mysqli" },
        { name = "MOODLE_DATABASE_PORT_NUMBER",  value = tostring(var.db_port) },
        { name = "MOODLE_DATABASE_NAME",         value = var.db_name },
        { name = "MOODLE_SITE_NAME",             value = var.moodle_site_name },
        { name = "MOODLE_USERNAME",              value = var.moodle_admin_user },
        { name = "MOODLE_EMAIL",                 value = var.moodle_admin_email },
        { name = "MOODLE_HOST",                  value = var.production_url },
        { name = "MOODLE_SKIP_BOOTSTRAP",        value = "no" },
        { name = "BITNAMI_DEBUG",                value = "false" },
        { name = "PHP_ENABLE_OPCACHE",           value = "yes" },
        { name = "PHP_MEMORY_LIMIT",             value = "512M" },
        { name = "PHP_MAX_EXECUTION_TIME",       value = "300" },
        { name = "PHP_POST_MAX_SIZE",            value = "100M" },
        { name = "PHP_UPLOAD_MAX_FILESIZE",      value = "100M" },
      ]

      secrets = [
        {
          name      = "MOODLE_DATABASE_HOST"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:host::"
        },
        {
          name      = "MOODLE_DATABASE_USER"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:username::"
        },
        {
          name      = "MOODLE_DATABASE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:password::"
        },
        {
          name      = "MOODLE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.moodle_admin.arn}:password::"
        },
      ]

      mountPoints = [
        {
          sourceVolume  = "moodle-app"
          containerPath = "/bitnami/moodle"
          readOnly      = false
        },
        {
          sourceVolume  = "moodledata"
          containerPath = "/bitnami/moodledata"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.moodle_app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "moodle"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/login/index.php || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 180
      }
    }
  ])

  tags = {
    Name        = "${var.client_name}_moodle_task"
    Environment = var.environment
  }
}

// ECS Service
resource "aws_ecs_service" "moodle" {
  name                   = "${var.client_name}-moodle"
  cluster                = aws_ecs_cluster.moodle.id
  task_definition        = aws_ecs_task_definition.moodle.arn
  desired_count          = var.ecs_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  // Wait for ALB to be healthy before considering deployment done
  health_check_grace_period_seconds = 300

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id,
    ]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.moodle.arn
    container_name   = "moodle"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_execution_managed,
    aws_efs_mount_target.private_a,
    aws_efs_mount_target.private_b,
    aws_efs_mount_target.private_c,
  ]

  tags = {
    Name        = "${var.client_name}_moodle_service"
    Environment = var.environment
  }
}

// Auto scaling
resource "aws_appautoscaling_target" "moodle" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.moodle.name}/${aws_ecs_service.moodle.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "moodle_cpu" {
  name               = "${var.client_name}-moodle-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.moodle.resource_id
  scalable_dimension = aws_appautoscaling_target.moodle.scalable_dimension
  service_namespace  = aws_appautoscaling_target.moodle.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "moodle_memory" {
  name               = "${var.client_name}-moodle-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.moodle.resource_id
  scalable_dimension = aws_appautoscaling_target.moodle.scalable_dimension
  service_namespace  = aws_appautoscaling_target.moodle.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 80
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
