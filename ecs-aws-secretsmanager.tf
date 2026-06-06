//*******************************************
// SECRETS MANAGER
// Credentials are stored as JSON secrets so the
// ECS task can fetch them at startup without
// embedding plaintext in task definitions.
//*******************************************

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.client_name}/moodle/db"
  description             = "Moodle RDS credentials"
  recovery_window_in_days = 7
  tags = { Name = "${var.client_name}_moodle_db_secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = var.db_master_password
    host     = aws_db_instance.moodle.address
    port     = tostring(var.db_port)
    dbname   = var.db_name
  })
}

resource "aws_secretsmanager_secret" "moodle_admin" {
  name                    = "${var.client_name}/moodle/admin"
  description             = "Moodle admin credentials"
  recovery_window_in_days = 7
  tags = { Name = "${var.client_name}_moodle_admin_secret" }
}

resource "aws_secretsmanager_secret_version" "moodle_admin" {
  secret_id = aws_secretsmanager_secret.moodle_admin.id
  secret_string = jsonencode({
    username = var.moodle_admin_user
    password = var.moodle_admin_password
    email    = var.moodle_admin_email
  })
}
