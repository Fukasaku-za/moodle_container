//*******************************************
// ALB — Application Load Balancer
//*******************************************

resource "aws_lb" "moodle" {
  name               = "${var.client_name}-moodle-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]

  enable_http2               = true
  enable_deletion_protection = var.deletion_protection

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = { Environment = var.environment }
}

// Port 80 — redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.moodle.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

// Port 443 — HTTPS forward to Moodle
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.moodle.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.moodle.arn
  }
}

// Target group — Fargate IP mode (not instance)
resource "aws_lb_target_group" "moodle" {
  name                 = "${var.client_name}-moodle-tg"
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

  tags = { Environment = var.environment }
}

output "alb_dns_name" {
  description = "Point your DNS CNAME to this ALB DNS name"
  value       = aws_lb.moodle.dns_name
}
