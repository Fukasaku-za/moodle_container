//*******************************************
// All Variable Declarations — Moodle ECS
//*******************************************

// ── AWS credentials ──────────────────────
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "af-south-1"
}

variable "aws_access_key" {
  type      = string
  sensitive = true
  default   = "required"
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
  default   = "required"
}

variable "aws_session_token" {
  type      = string
  sensitive = true
  default   = "required"
}

// ── Client / environment ─────────────────
variable "client_name" {
  type        = string
  description = "Short client identifier used in resource names"
}

variable "environment" {
  type        = string
  description = "Environment label (production, staging)"
  default     = "production"
}

variable "production_url" {
  type        = string
  description = "Primary domain for the Moodle site e.g. learn.example.com"
}

// ── Networking ────────────────────────────
variable "vpc_cidr" {
  type        = string
  description = "First two octets of the VPC CIDR"
  default     = "10.0"
}

// ── ECS / Container ───────────────────────
variable "moodle_image" {
  type        = string
  description = "Container image to run — use ECR URI after first push, or bitnami/moodle for bootstrap"
  default     = "bitnami/moodle:latest"
}

variable "ecs_task_cpu" {
  type        = number
  description = "Fargate task CPU units (256 / 512 / 1024 / 2048 / 4096)"
  default     = 1024
}

variable "ecs_task_memory" {
  type        = number
  description = "Fargate task memory in MiB"
  default     = 2048
}

variable "ecs_desired_count" {
  type        = number
  description = "Number of running Moodle containers"
  default     = 1
}

variable "moodle_site_name" {
  type        = string
  description = "Moodle site display name"
  default     = "Moodle LMS"
}

variable "moodle_admin_user" {
  type        = string
  description = "Moodle admin username"
  default     = "admin"
}

variable "moodle_admin_password" {
  type        = string
  description = "Moodle admin password — set via TF_VAR or TFC workspace variable"
  sensitive   = true
}

variable "moodle_admin_email" {
  type        = string
  description = "Moodle admin email address"
}

// ── Database ──────────────────────────────
variable "db_instance_class" {
  type    = string
  default = "db.t3.small"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_engine_version" {
  type    = string
  default = "8.4.8"
}

variable "db_parameter_family" {
  type    = string
  default = "mysql8.4"
}

variable "db_master_username" {
  type    = string
  default = "moodle_user"
}

variable "db_master_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "moodle"
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "db_snapshot_identifier" {
  type        = string
  description = "Snapshot ARN to restore from. Leave empty for fresh database."
  default     = ""
}

variable "deletion_protection" {
  type    = bool
  default = true
}

// ── ALB ───────────────────────────────────
variable "alb_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener"
}

variable "alb_health_check_path" {
  type    = string
  default = "/login/index.php"
}

// ── Monitoring ────────────────────────────
variable "monitoring_email" {
  type    = string
  description = "Email address for CloudWatch alarm notifications"
}

variable "retention_days" {
  type    = number
  default = 731
}

// ── Backup ───────────────────────────────
variable "backup_retention_days" {
  type    = number
  default = 14
}
