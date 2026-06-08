//*******************************************
// MULTI-TENANT ECS — NEW CLIENTS (for_each)
//
// IMPORTANT: This does NOT modify the existing oneconnect Terraform
// resources. New tenants SHARE the existing aws_db_instance.moodle, but
// each gets its own database + user created inside it at container startup,
// so oneconnect's "moodle" database is never touched. The live site at
// app.learngrc.xyz keeps serving via the listener's default_action.
//
// Per client you: (1) set vars in new_clients + client_secrets, (2) apply,
// (3) push that client's image to its new ECR repo, (4) force a deploy.
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

// ── Tenant ECR Repositories (one repo per client) ─────
// Each client gets its own repo: <client>/moodle. Push that client's
// image here, then the task definition below pulls from it by tag.
resource "aws_ecr_repository" "tenant" {
  for_each = var.new_clients

  name                 = "${each.key}/moodle"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${each.key}_moodle_ecr", Client = each.key }
}

resource "aws_ecr_lifecycle_policy" "tenant" {
  for_each = var.new_clients

  repository = aws_ecr_repository.tenant[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 1 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
        action       = { type = "expire" }
      }
    ]
  })
}

// NOTE: No per-tenant RDS anymore. All tenants share aws_db_instance.moodle.
// Each tenant gets its OWN database + scoped user ON that shared instance,
// created by the container at startup via the MYSQL_CLIENT_CREATE_* vars
// in the task definition below (your logs already show the image validates
// MYSQL_CLIENT_* env vars, so this path is supported).

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
      image        = "${aws_ecr_repository.tenant[each.key].repository_url}:${each.value.image_tag}"
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]

      environment = [
        { name = "MOODLE_DATABASE_TYPE", value = "mysqli" },
        // ── App connects to its OWN database/user on the SHARED instance ──
        { name = "MOODLE_DATABASE_HOST", value = aws_db_instance.moodle.address },
        { name = "MOODLE_DATABASE_PORT_NUMBER", value = tostring(var.db_port) },
        { name = "MOODLE_DATABASE_NAME", value = each.key },
        { name = "MOODLE_DATABASE_USER", value = "${each.key}_user" },
        { name = "MOODLE_DATABASE_PASSWORD", value = var.client_secrets[each.key].db_password },
        // ── Create that database + user on first boot, using the shared
        //    RDS master credential as "root". (See isolation note in chat.) ──
        { name = "MYSQL_CLIENT_FLAVOR", value = "mysql" },
        { name = "MYSQL_CLIENT_DATABASE_HOST", value = aws_db_instance.moodle.address },
        { name = "MYSQL_CLIENT_DATABASE_PORT_NUMBER", value = tostring(var.db_port) },
        { name = "MYSQL_CLIENT_DATABASE_ROOT_USER", value = var.db_master_username },
        { name = "MYSQL_CLIENT_DATABASE_ROOT_PASSWORD", value = var.db_master_password },
        { name = "MYSQL_CLIENT_CREATE_DATABASE_NAME", value = each.key },
        { name = "MYSQL_CLIENT_CREATE_DATABASE_USER", value = "${each.key}_user" },
        { name = "MYSQL_CLIENT_CREATE_DATABASE_PASSWORD", value = var.client_secrets[each.key].db_password },
        { name = "MYSQL_CLIENT_CREATE_DATABASE_CHARACTER_SET", value = "utf8mb4" },
        { name = "MYSQL_CLIENT_CREATE_DATABASE_COLLATE", value = "utf8mb4_unicode_ci" },
        // ── Moodle site ──
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

output "tenant_ecr_repos" {
  description = "Push each client's image to its repo, then run tenant_force_deploy"
  value       = { for k, r in aws_ecr_repository.tenant : k => r.repository_url }
}

output "tenant_force_deploy" {
  description = "Run after pushing a new image for a tenant"
  value = {
    for k, s in aws_ecs_service.tenant :
    k => "aws ecs update-service --cluster ${aws_ecs_cluster.moodle.name} --service ${s.name} --force-new-deployment --region ${var.aws_region}"
  }
}
