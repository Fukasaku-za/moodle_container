//*******************************************
// VPC & FLOW LOGGING
//*******************************************

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = { Name = "${var.client_name}_vpc" }
}

// CloudWatch flow log
resource "aws_flow_log" "flowlog_cloudwatch" {
  iam_role_arn    = aws_iam_role.flowlog_role.arn
  log_destination = aws_cloudwatch_log_group.flowlog.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id
  tags = { Name = "${var.client_name}_cloudwatch_flowlog" }
}

resource "aws_cloudwatch_log_group" "flowlog" {
  name              = "/aws/vpc/${var.client_name}/flowlogs"
  retention_in_days = var.retention_days
}

resource "aws_iam_role" "flowlog_role" {
  name               = "${var.client_name}_flowlog_role"
  assume_role_policy = data.aws_iam_policy_document.flowlog_assume.json
}

data "aws_iam_policy_document" "flowlog_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "flowlog_policy" {
  name   = "${var.client_name}_flowlog_policy"
  role   = aws_iam_role.flowlog_role.id
  policy = data.aws_iam_policy_document.flowlog_permissions.json
}

data "aws_iam_policy_document" "flowlog_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

// S3 flow log
resource "aws_flow_log" "flowlog_s3" {
  log_destination      = aws_s3_bucket.flowlog.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.vpc.id
  tags = { Name = "${var.client_name}_s3_flowlog" }
}
