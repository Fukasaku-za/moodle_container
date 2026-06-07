//*******************************************
// IAM — ECS Roles
//*******************************************

// ── Execution role ────────────────────────
// Used by the ECS agent to pull images from ECR
// and inject secrets into the container environment.
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.client_name}_ecs_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags = { Name = "${var.client_name}_ecs_execution_role" }
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// Extra policy allowing the execution role to read secrets and decrypt with KMS
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "${var.client_name}_ecs_execution_secrets"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
    resources = [
      aws_secretsmanager_secret.db.arn,
      aws_secretsmanager_secret.moodle_admin.arn,
    ]
  }
}

// ── Task role ─────────────────────────────
// Used by the running Moodle container itself.
// Grants CloudWatch Logs, SSM exec, and EFS access.
resource "aws_iam_role" "ecs_task" {
  name               = "${var.client_name}_ecs_task_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags = { Name = "${var.client_name}_ecs_task_role" }
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name   = "${var.client_name}_ecs_task_policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_permissions.json
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  // ECS Exec (allows `aws ecs execute-command` for debugging)
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  // S3 access for Moodle file storage (optional — remove if not using S3 file store)
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.moodle_files.arn,
      "${aws_s3_bucket.moodle_files.arn}/*",
    ]
  }
}
