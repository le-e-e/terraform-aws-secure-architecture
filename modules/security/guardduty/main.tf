resource "aws_guardduty_detector" "main" {
  count = var.enable ? 1 : 0
  enable = true
  finding_publishing_frequency = var.finding_publishing_frequency

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-guardduty"
      Type = "GuardDuty"
    }
  )
}

resource "aws_guardduty_publishing_destination" "main" {
  count = var.enable ? 1 : 0
  detector_id = aws_guardduty_detector.main[0].id
  destination_type = "S3"
  destination_arn = aws_s3_bucket.guardduty_s3_bucket.arn
  kms_key_arn = aws_kms_key.guardduty_s3_bucket_kms_key.arn
  depends_on = [aws_s3_bucket_policy.guardduty_s3_bucket]
}

resource "aws_s3_bucket" "guardduty_s3_bucket" {
  bucket = var.guardduty_s3_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "guardduty_s3_bucket" {
  bucket = aws_s3_bucket.guardduty_s3_bucket.id
  block_public_acls = var.public_access_block
  block_public_policy = var.public_access_block
  ignore_public_acls = var.public_access_block
  restrict_public_buckets = var.public_access_block
}

resource "aws_s3_bucket_versioning" "guardduty_s3_bucket" {
  bucket = aws_s3_bucket.guardduty_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty_s3_bucket" {
  bucket = aws_s3_bucket.guardduty_s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.guardduty_s3_bucket_kms_key.id
    }
  }
}

resource "aws_s3_bucket_policy" "guardduty_s3_bucket" {
  bucket = aws_s3_bucket.guardduty_s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSGuardDutyAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.guardduty_s3_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${var.guardduty_kms_key_account_id}"
          }
        }
      },
      {
        Sid    = "AWSGuardDutyWrite"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.guardduty_s3_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = "${var.guardduty_kms_key_account_id}"
          }
        }
      }
    ]
  })
}

resource "aws_kms_key" "guardduty_s3_bucket_kms_key" {
  description = "GuardDuty S3 Bucket KMS Key"
  deletion_window_in_days = var.guardduty_s3_bucket_kms_key_deletion_window_in_days
  enable_key_rotation = var.guardduty_s3_bucket_kms_key_enable_key_rotation
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.guardduty_kms_key_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "AllowGuardDutyUseKey"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${var.guardduty_kms_key_account_id}"
          }
        }
      }
    ]
  })
  tags = var.tags
}