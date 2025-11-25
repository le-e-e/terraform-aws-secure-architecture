resource "aws_cloudtrail" "main" {
    name = var.cloudtrail_name
    s3_bucket_name = var.cloudtrail_bucket_name
    s3_key_prefix = var.cloudtrail_s3_key_prefix
    is_multi_region_trail = true
    enable_logging = true
    tags = var.tags
    depends_on = [aws_s3_bucket.cloudtrail_bucket, aws_s3_bucket_policy.cloudtrail_bucket]
}

resource "aws_kms_key" "cloudtrail_bucket_kms_key" {
  description = "CloudTrail Bucket KMS Key"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.cloudtrail_bucket_kms_key_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailUseKey"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${var.cloudtrail_bucket_kms_key_account_id}"
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${var.cloudtrail_bucket_kms_key_account_id}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = "${var.cloudtrail_bucket_kms_key_account_id}"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = var.cloudtrail_bucket_name
  tags = var.tags
}

# 퍼블릭 엑세스 차단 설정
resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  block_public_acls = var.public_access_block
  block_public_policy = var.public_access_block
  ignore_public_acls = var.public_access_block
  restrict_public_buckets = var.public_access_block
}

resource "aws_s3_bucket_versioning" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      #  aws:kms는 유료
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudtrail_bucket_kms_key.id
    }
  }
}