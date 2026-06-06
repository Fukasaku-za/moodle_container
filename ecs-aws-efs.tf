//*******************************************
// EFS — Persistent Moodle Data
// Moodle requires shared persistent storage for:
//   /bitnami/moodle       — application files / plugins
//   /bitnami/moodledata   — user uploads, cache, sessions
// EFS gives all Fargate tasks access to the same files,
// which is required for multi-task deployments.
//*******************************************

resource "aws_efs_file_system" "moodle" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = { Name = "${var.client_name}_moodle_efs" }
}

// Mount targets — one per private subnet so any AZ can reach EFS
resource "aws_efs_mount_target" "private_a" {
  file_system_id  = aws_efs_file_system.moodle.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "private_b" {
  file_system_id  = aws_efs_file_system.moodle.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "private_c" {
  file_system_id  = aws_efs_file_system.moodle.id
  subnet_id       = aws_subnet.private_c.id
  security_groups = [aws_security_group.efs.id]
}

// Access point for moodle app directory
resource "aws_efs_access_point" "moodle_app" {
  file_system_id = aws_efs_file_system.moodle.id

  posix_user {
    uid = 1001
    gid = 1001
  }

  root_directory {
    path = "/moodle"
    creation_info {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "755"
    }
  }

  tags = { Name = "${var.client_name}_moodle_app_ap" }
}

// Access point for moodledata directory
resource "aws_efs_access_point" "moodledata" {
  file_system_id = aws_efs_file_system.moodle.id

  posix_user {
    uid = 1001
    gid = 1001
  }

  root_directory {
    path = "/moodledata"
    creation_info {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "755"
    }
  }

  tags = { Name = "${var.client_name}_moodledata_ap" }
}

// Backup policy for EFS
resource "aws_efs_backup_policy" "moodle" {
  file_system_id = aws_efs_file_system.moodle.id
  backup_policy {
    status = "ENABLED"
  }
}
