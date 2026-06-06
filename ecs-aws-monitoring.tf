//*******************************************
// MONITORING — CloudWatch Alarms & SNS
//*******************************************

resource "aws_sns_topic" "alerts" {
  name              = "${var.client_name}-moodle-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn                       = aws_sns_topic.alerts.arn
  protocol                        = "email"
  endpoint                        = var.monitoring_email
  confirmation_timeout_in_minutes = 1
  endpoint_auto_confirms          = false
}

// ── ECS Alarms ────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${var.client_name}-moodle-ecs-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "breaching"
  alarm_description   = "High CPU on Moodle ECS service"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = aws_ecs_cluster.moodle.name
    ServiceName = aws_ecs_service.moodle.name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${var.client_name}-moodle-ecs-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "breaching"
  alarm_description   = "High memory on Moodle ECS service"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = aws_ecs_cluster.moodle.name
    ServiceName = aws_ecs_service.moodle.name
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_count" {
  alarm_name          = "${var.client_name}-moodle-ecs-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_description   = "No running Moodle tasks"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = aws_ecs_cluster.moodle.name
    ServiceName = aws_ecs_service.moodle.name
  }
}

// ── ALB Alarms ────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "${var.client_name}-moodle-alb-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "breaching"
  alarm_description   = "Unhealthy Moodle targets behind ALB"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    TargetGroup  = aws_lb_target_group.moodle.arn_suffix
    LoadBalancer = aws_lb.moodle.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.client_name}-moodle-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "High 5XX errors on Moodle ALB"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    TargetGroup  = aws_lb_target_group.moodle.arn_suffix
    LoadBalancer = aws_lb.moodle.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.client_name}-moodle-alb-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_description   = "High ALB response time for Moodle"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    TargetGroup  = aws_lb_target_group.moodle.arn_suffix
    LoadBalancer = aws_lb.moodle.arn_suffix
  }
}

// ── RDS Alarms ────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.client_name}-moodle-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "breaching"
  alarm_description   = "High CPU on Moodle RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = { DBInstanceIdentifier = aws_db_instance.moodle.identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.client_name}-moodle-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 5368709120
  treat_missing_data  = "breaching"
  alarm_description   = "Low storage on Moodle RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = { DBInstanceIdentifier = aws_db_instance.moodle.identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  alarm_name          = "${var.client_name}-moodle-rds-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 209715200
  treat_missing_data  = "breaching"
  alarm_description   = "Low memory on Moodle RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = { DBInstanceIdentifier = aws_db_instance.moodle.identifier }
}

// ── CloudWatch Dashboard ──────────────────

resource "aws_cloudwatch_dashboard" "moodle" {
  dashboard_name = "${var.client_name}-moodle"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", x = 0, y = 0, width = 6, height = 4, properties = {
        title   = "ECS CPU"
        metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.moodle.name, "ServiceName", aws_ecs_service.moodle.name]]
        period  = 60, stat = "Average", region = var.aws_region
      }},
      { type = "metric", x = 6, y = 0, width = 6, height = 4, properties = {
        title   = "ECS Memory"
        metrics = [["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.moodle.name, "ServiceName", aws_ecs_service.moodle.name]]
        period  = 60, stat = "Average", region = var.aws_region
      }},
      { type = "metric", x = 12, y = 0, width = 6, height = 4, properties = {
        title   = "ALB Request Count"
        metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.moodle.arn_suffix]]
        period  = 60, stat = "Sum", region = var.aws_region
      }},
      { type = "metric", x = 18, y = 0, width = 6, height = 4, properties = {
        title   = "ALB 5XX Errors"
        metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.moodle.arn_suffix]]
        period  = 60, stat = "Sum", region = var.aws_region
      }},
      { type = "metric", x = 0, y = 5, width = 6, height = 4, properties = {
        title   = "RDS CPU"
        metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.moodle.identifier]]
        period  = 60, stat = "Average", region = var.aws_region
      }},
      { type = "metric", x = 6, y = 5, width = 6, height = 4, properties = {
        title   = "RDS Free Storage"
        metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.moodle.identifier]]
        period  = 60, stat = "Average", region = var.aws_region
      }},
      { type = "metric", x = 12, y = 5, width = 6, height = 4, properties = {
        title   = "RDS Connections"
        metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.moodle.identifier]]
        period  = 60, stat = "Average", region = var.aws_region
      }},
      { type = "metric", x = 18, y = 5, width = 6, height = 4, properties = {
        title   = "ALB Response Time"
        metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.moodle.arn_suffix]]
        period  = 60, stat = "Average", region = var.aws_region
      }},
    ]
  })
}
