//*******************************************
// MULTI-TENANT ECS — NEW CLIENTS (for_each)
//
// IMPORTANT: This intentionally does NOT touch the existing oneconnect
// resources (aws_ecs_service.moodle, aws_db_instance.moodle, etc.).
// Those keep serving app.learngrc.xyz exactly as today. Only NEW tenants
// are driven through the map below, so applying this cannot disturb the
// live site or the live database.
//
// To add a client: add an entry to var.new_clients + var.client_secrets,
// then `terraform apply`. DNS for the new subdomain points at the SAME
// shared ALB (aws_lb.moodle) — output alb_dns_name.
//*******************************************

// ── Tenant Target Groups ──────────────────
resource "aws_lb_target_group" "tenant" {
  for_each = var.new_clients

  name                 = "${each.key}-moodle-tg" // must stay <= 32 chars
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.vpc.id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.alb_health_check_path
    port                = "8080"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200,302"
  }

  tags = { Name = "${each.key}-moodle-tg", Client = each.key }
}

// ── Host-header routing on the existing HTTPS listener ─
// The listener's default_action is left pointing at oneconnect's TG,
// so app.learngrc.xyz is unaffected. Each tenant gets an explicit rule.
resource "aws_lb_listener_rule" "tenant" {
  for_each = var.new_clients

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority // explicit + stable (no index() churn)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tenant[each.key].arn
  }

  condition {
    host_header {
      values = ["${each.value.subdomain}.${var.saas_domain}"]
    }
  }
}

// ── Tenant Databases (one isolated RDS per tenant) ────
// Reuses the shared subnet group / parameter group / monitoring role / SG.
// Set shared_database=true logic instead if you prefer one RDS for all.
resource "aws_db_instance" "tenant" {
  for_each = var.new_clients

  identifier            = "${each.key}-moodle-db"
  engine                = "mysql"
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = each.value.db_name
  username = each.value.db_username
  password = var.client_secrets[each.key].db_password // sensitive, from TF_VAR
  port     = var.db_port

  multi_az            = false
  publicly_accessible = false

  db_subnet_group_name   = aws_db_subnet_group.moodle.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.moodle.name

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  auto_minor_version_upgrade      = true
  maintenance_window              = "Sun:00:00-Sun:01:00"

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  performance_insights_enabled = false

  deletion_protection       = var.deletion_protection
  delete_automated_backups  = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "${each.key}-moodle-db-final"
  copy_tags_to_snapshot     = true
  apply_immediately         = false

  tags = {
    Name        = "${each.key}_moodle_db"
    Environment = var.environment
    Client      = each.key
  }

  timeouts {
    create = "2h"
    update = "2h"
    delete = "2h"
  }
}

// ── Tenant Log Groups ─────────────────────
resource "aws_cloudwatch_log_group" "tenant" {
  for_each = var.new_clients

  name              = "/ecs/${each.key}-moodle"
  retention_in_days = 30
  tags              = { Client = each.key }
}

// ── Tenant Task Definitions ───────────────
resource "aws_ecs_task_definition" "tenant" {
  for_each = var.new_clients

  family                   = "${each.key}-moodle"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name         = "moodle"
      image        = each.value.image // per-tenant image, NOT hardcoded
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]

      environment = [
        { name = "MOODLE_DATABASE_TYPE", value = "mysqli" },
        { name = "MOODLE_DATABASE_HOST", value = aws_db_instance.tenant[each.key].address },
        { name = "MOODLE_DATABASE_PORT_NUMBER", value = tostring(var.db_port) },
        { name = "MOODLE_DATABASE_NAME", value = each.value.db_name },
        { name = "MOODLE_DATABASE_USER", value = each.value.db_username },
        { name = "MOODLE_DATABASE_PASSWORD", value = var.client_secrets[each.key].db_password },
        { name = "MOODLE_USERNAME", value = each.value.admin_user },
        { name = "MOODLE_PASSWORD", value = var.client_secrets[each.key].admin_password },
        { name = "MOODLE_EMAIL", value = each.value.admin_email },
        { name = "MOODLE_SITE_NAME", value = each.value.site_name },
        { name = "MOODLE_URL", value = "https://${each.value.subdomain}.${var.saas_domain}" },
        { name = "MOODLE_SKIP_BOOTSTRAP", value = "no" },
        { name = "BITNAMI_DEBUG", value = "true" },
        // Moodle sits behind the ALB which terminates TLS — without these
        // it builds http:// URLs and can redirect-loop after it boots.
        { name = "MOODLE_REVERSEPROXY", value = "yes" },
        { name = "MOODLE_SSLPROXY", value = "yes" }
      ]

      // Send stdout/stderr to CloudWatch so failures are visible.
      // Execution role's AmazonECSTaskExecutionRolePolicy already grants
      // CreateLogStream + PutLogEvents; the group is pre-created below.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.tenant[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "moodle"
        }
      }
    }
  ])

  tags = { Name = "${each.key}-moodle-task-def", Client = each.key }
}

// ── Tenant ECS Services ───────────────────
resource "aws_ecs_service" "tenant" {
  for_each = var.new_clients

  name            = "${each.key}-moodle-service"
  cluster         = aws_ecs_cluster.moodle.id
  task_definition = aws_ecs_task_definition.tenant[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id
    ]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false // private subnets + VPC endpoints, same as oneconnect
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tenant[each.key].arn
    container_name   = "moodle"
    container_port   = 8080
  }

  // Endpoints must exist before tasks try to pull from ECR / reach AWS APIs
  depends_on = [
    aws_lb_listener.https,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr
  ]

  tags = { Name = "${each.key}-moodle-service", Client = each.key }
}

// ── Outputs ───────────────────────────────
output "tenant_urls" {
  description = "All tenant URLs (oneconnect + new clients)"
  value = merge(
    { oneconnect = "https://${var.production_url}" },
    { for k, c in var.new_clients : k => "https://${c.subdomain}.${var.saas_domain}" }
  )
}

output "tenant_force_deploy" {
  description = "Run after pushing a new image for a tenant"
  value = {
    for k, s in aws_ecs_service.tenant :
    k => "aws ecs update-service --cluster ${aws_ecs_cluster.moodle.name} --service ${s.name} --force-new-deployment --region ${var.aws_region}"
  }
}
