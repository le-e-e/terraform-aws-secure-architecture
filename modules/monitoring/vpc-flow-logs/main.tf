data "aws_caller_identity" "current" {}

resource "aws_flow_log" "main" {
  log_destination = aws_s3_bucket.vpc_flow_logs_bucket.arn
  log_destination_type = "s3"

  vpc_id = var.vpc_id

  traffic_type = var.traffic_type
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc-flow-logs"
      Type = "VPCFlowLogs"
    }
  )
}

resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  bucket = var.vpc_flow_logs_bucket_name
  
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
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.vpc_flow_logs_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.vpc_flow_logs_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}" 
          }
        }
      }
    ]
  })
}


resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  rule {
    id     = "vpc-flow-logs-bucket-lifecycle-configuration"
    status = "Enabled"

    # 30일 후 Glacier로 전환
    transition {
      days          = var.lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    # 90일 후 Deep Archive로 전환
    transition {
      days          = var.lifecycle_deep_archive_days
      storage_class = "DEEP_ARCHIVE"
    }

    # 불완전한 멀티파트 업로드 7일 후 삭제 (비용 절감)
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # 만료 설정 (0이면 만료 없음)
    dynamic "expiration" {
      for_each = var.lifecycle_expiration_days > 0 ? [1] : []
      content {
        days                        = var.lifecycle_expiration_days
        expired_object_delete_marker = true
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vpc_flow_logs_bucket" {
  count = var.enable_public_access_block ? 1 : 0

  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "vpc_flow_logs_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# KMS 키 (encryption_type이 kms일 때만 생성)
resource "aws_kms_key" "main" {
  count = var.encryption_type == "kms" ? 1 : 0

  description             = "VPC Flow Logs Bucket KMS Key"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowFlowLogsEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
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
        Sid    = "AllowS3BucketDecrypt"
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
          StringLike = {
            "aws:SourceArn" = "${aws_s3_bucket.vpc_flow_logs_bucket.arn}"
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

resource "aws_kms_alias" "main" {
  count = var.encryption_type == "kms" ? 1 : 0

  name          = "alias/${var.project_name}-vpc-flow-logs"
  target_key_id = aws_kms_key.main[0].key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logflow_bucket" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type == "kms" ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_type == "kms" ? aws_kms_key.main[0].arn : null
    }
  }
}