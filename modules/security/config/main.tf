resource "aws_config_configuration_recorder" "main" {
  name = var.config_configuration_recorder_name
  role_arn = aws_iam_role.config[0].arn
  recording_group {
    all_supported = true
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  name = var.config_configuration_recorder_name
  is_enabled = true
  depends_on = [aws_config_configuration_recorder.main, aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  name = var.config_delivery_channel_name
  s3_bucket_name = var.config_delivery_channel_s3_bucket_name
  s3_key_prefix = var.config_delivery_channel_s3_key_prefix
  sns_topic_arn = var.config_delivery_channel_sns_topic_arn
  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_s3_bucket" "config" {
  bucket = var.config_delivery_channel_s3_bucket_name
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.config.id
  block_public_acls = var.public_access_block
  block_public_policy = var.public_access_block
  ignore_public_acls = var.public_access_block
  restrict_public_buckets = var.public_access_block
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "config" {
  description = "Config S3 Bucket KMS Key"
  deletion_window_in_days = var.config_delivery_channel_s3_bucket_kms_key_deletion_window_in_days
  enable_key_rotation = var.config_delivery_channel_s3_bucket_kms_key_enable_key_rotation
  tags = var.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.config_delivery_channel_s3_bucket_kms_key_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "AllowConfigUseKey"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${var.config_delivery_channel_s3_bucket_kms_key_account_id}"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      #  aws:kms는 유료
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.config.arn
    }
  }
}

resource "aws_s3_bucket_policy" "config_bucket" {
  bucket = aws_s3_bucket.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${var.config_delivery_channel_s3_bucket_kms_key_account_id}"
          }
        }
      },
      {
        Sid    = "AWSConfigWrite"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = "${var.config_delivery_channel_s3_bucket_kms_key_account_id}"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role" "config" {
  count = var.enable ? 1 : 0

  name = var.config_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = var.config_role_policy_arn
}