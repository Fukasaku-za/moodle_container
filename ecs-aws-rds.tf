//*******************************************
// RDS — MySQL 8.4 for Moodle
//*******************************************

resource "aws_db_instance" "moodle" {
  identifier            = "${var.client_name}-moodle-db"
  engine                = "mysql"
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_master_username
  password = var.db_master_password
  port     = var.db_port

  snapshot_identifier = var.db_snapshot_identifier != "" ? var.db_snapshot_identifier : null

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

  performance_insights_enabled = true

  deletion_protection      = var.deletion_protection
  delete_automated_backups = false
  skip_final_snapshot      = false
  final_snapshot_identifier = "${var.client_name}-moodle-db-final"
  copy_tags_to_snapshot    = true
  apply_immediately        = false

  tags = {
    Name        = "${var.client_name}_moodle_db"
    Environment = var.environment
  }

  timeouts {
    create = "2h"
    update = "2h"
    delete = "2h"
  }
}

resource "aws_db_subnet_group" "moodle" {
  name       = "${var.client_name}_moodle_db_subnet_group"
  subnet_ids = [aws_subnet.database_a.id, aws_subnet.database_b.id, aws_subnet.database_c.id]
  tags = { Name = "${var.client_name}_moodle_db_subnet_group" }
}

resource "aws_db_parameter_group" "moodle" {
  name        = "${var.client_name}-moodle-mysql84"
  family      = var.db_parameter_family
  description = "Parameter group for Moodle MySQL 8.4 - ${var.client_name}"

  parameter {
    apply_method = "pending-reboot"
    name         = "innodb_file_per_table"
    value        = "1"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_allowed_packet"
    value = "67108864"
  }
}

// Enhanced monitoring role
resource "aws_iam_role" "rds_monitoring" {
  name_prefix        = "rds-monitoring-${var.client_name}-"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
}

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

// RDS event subscription
resource "aws_db_event_subscription" "moodle" {
  name      = "${var.client_name}-moodle-rds-events"
  sns_topic = aws_sns_topic.alerts.arn

  source_type = "db-instance"
  source_ids  = [aws_db_instance.moodle.identifier]

  event_categories = [
    "availability", "backup", "configuration change",
    "deletion", "failover", "failure", "low storage",
    "maintenance", "recovery", "restoration",
  ]
}
