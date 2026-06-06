//*******************************************
// SECURITY GROUPS
//*******************************************

// ALB — public-facing HTTP/HTTPS
resource "aws_security_group" "alb" {
  name        = "${var.client_name}_alb_sg"
  description = "ALB: HTTP and HTTPS from internet"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.client_name}_alb_sg" }
}

// ECS tasks — accept HTTP only from ALB
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.client_name}_ecs_tasks_sg"
  description = "Moodle ECS tasks: HTTP from ALB only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.client_name}_ecs_tasks_sg" }
}

// RDS — MySQL from ECS tasks only
resource "aws_security_group" "rds" {
  name        = "${var.client_name}_rds_sg"
  description = "RDS: MySQL from ECS tasks only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "MySQL from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.client_name}_rds_sg" }
}

// EFS — NFS from ECS tasks only
resource "aws_security_group" "efs" {
  name        = "${var.client_name}_efs_sg"
  description = "EFS: NFS from ECS tasks only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "NFS from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.client_name}_efs_sg" }
}
