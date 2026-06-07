//*******************************************
// ECS CLUSTER, SERVICE & TASK DEFINITION
//*******************************************

// ── ECS Cluster ──────────────────────────
resource "aws_ecs_cluster" "moodle" {
  name = "${var.client_name}-moodle-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.client_name}-moodle-cluster"
  }
}

// ── ECS Task Definition ──────────────────
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
      image = "public.ecr.aws/bitnami/moodle:5.2.0-debian-12-r4"  # ECR Public image
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      # Using environment variables directly
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
    }
  ])

  tags = {
    Name = "${var.client_name}-moodle-task-def"
  }
}

// ── ECS Service ──────────────────────────
resource "aws_ecs_service" "moodle" {
  name            = "${var.client_name}-moodle-service"
  cluster         = aws_ecs_cluster.moodle.id
  task_definition = aws_ecs_task_definition.moodle.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  
  enable_execute_command = true

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id
    ]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.moodle.arn
    container_name   = "moodle"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.https,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr
  ]

  tags = {
    Name = "${var.client_name}-moodle-service"
  }
}
