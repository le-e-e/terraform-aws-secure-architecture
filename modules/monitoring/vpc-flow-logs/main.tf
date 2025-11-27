resource "aws_flow_log" "main" {
  log_destination = aws_s3_bucket.vpc_flow_logs_bucket.arn
  log_destination_type = "s3"

  vpc_id = var.vpc_id

  traffic_type = "ALL"
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-flow-logs"
      Type = "VPCFlowLogs"
    }
  )
}

resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  bucket = "${var.project_name}-vpc-flow-logs-bucket"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-flow-logs-bucket"
    }
  )
}

resource "aws_s3_bucket_policy" "vpc_flow_logs_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.vpc_flow_logs_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  rule {
    id = "vpc-flow-logs-bucket-lifecycle-configuration"
    filter {
      prefix = "vpc-flow-logs/"
    }
    transition {
      days = 30
      storage_class = "GLACIER"
    }
    transition {
      days = 60
      storage_class = "DEEP_ARCHIVE"
    }
    expiration {
      days = 365
      expired_object_delete_marker = true
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "vpc_flow_logs_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "vpc_flow_logs_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "main" {
  description = "VPC Flow Logs Bucket KMS Key"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "AllowVPCFlowLogsUseKey"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
        }
      },
      {
        Sid = "AllowS3UseKey"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-flow-logs-kms-key"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logflow_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}