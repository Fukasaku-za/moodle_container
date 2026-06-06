//*******************************************
// S3 BUCKETS
//*******************************************

locals {
  elb_account_id = "098369216593"
}

// ── ALB Access Logs ───────────────────────
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.client_name}-moodle-alb-logs"
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_acl" "alb_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.alb_logs]
  bucket     = aws_s3_bucket.alb_logs.id
  acl        = "private"
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-alb-logs-${var.retention_days}-days"
    status = "Enabled"
    filter {}
    expiration { days = var.retention_days }
    noncurrent_version_expiration { noncurrent_days = var.retention_days }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid     = "AllowELBPut"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.elb_account_id}:root"]
    }
  }
  statement {
    sid     = "AllowLogDeliveryPut"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }
  statement {
    sid     = "AllowLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.alb_logs.arn]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }
  statement {
    sid     = "DenyNonTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [aws_s3_bucket.alb_logs.arn, "${aws_s3_bucket.alb_logs.arn}/*"]
    principals { type = "AWS"; identifiers = ["*"] }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

// ── VPC Flow Logs ─────────────────────────
resource "aws_s3_bucket" "flowlog" {
  bucket = "${var.client_name}-moodle-vpc-flowlogs"
}

resource "aws_s3_bucket_ownership_controls" "flowlog" {
  bucket = aws_s3_bucket.flowlog.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_acl" "flowlog" {
  depends_on = [aws_s3_bucket_ownership_controls.flowlog]
  bucket     = aws_s3_bucket.flowlog.id
  acl        = "private"
}

resource "aws_s3_bucket_public_access_block" "flowlog" {
  bucket                  = aws_s3_bucket.flowlog.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "flowlog" {
  bucket = aws_s3_bucket.flowlog.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flowlog" {
  bucket = aws_s3_bucket.flowlog.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flowlog" {
  bucket = aws_s3_bucket.flowlog.id
  rule {
    id     = "expire-flowlogs-${var.retention_days}-days"
    status = "Enabled"
    filter {}
    expiration { days = var.retention_days }
    noncurrent_version_expiration { noncurrent_days = var.retention_days }
  }
}

resource "aws_s3_bucket_policy" "flowlog" {
  bucket = aws_s3_bucket.flowlog.id
  policy = data.aws_iam_policy_document.flowlog_s3.json
}

data "aws_iam_policy_document" "flowlog_s3" {
  statement {
    sid     = "AWSLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.flowlog.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals { type = "Service"; identifiers = ["delivery.logs.amazonaws.com"] }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid     = "AWSLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.flowlog.arn]
    principals { type = "Service"; identifiers = ["delivery.logs.amazonaws.com"] }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  statement {
    sid     = "DenyNonTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [aws_s3_bucket.flowlog.arn, "${aws_s3_bucket.flowlog.arn}/*"]
    principals { type = "AWS"; identifiers = ["*"] }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

// ── Moodle File Store (optional S3 file store) ────
resource "aws_s3_bucket" "moodle_files" {
  bucket = "${var.client_name}-moodle-files"
}

resource "aws_s3_bucket_public_access_block" "moodle_files" {
  bucket                  = aws_s3_bucket.moodle_files.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "moodle_files" {
  bucket = aws_s3_bucket.moodle_files.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "moodle_files" {
  bucket = aws_s3_bucket.moodle_files.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
