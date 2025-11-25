resource "aws_kms_key" "main" {
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation = var.enable_key_rotation
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.cloudwatch_to_s3_kms_key_account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "AllowCloudWatchLogsUseKey"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
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
            "aws:SourceAccount" = "${var.cloudwatch_to_s3_kms_key_account_id}"
          }
        }
      },
      {
        Sid = "AllowFirehoseUseKey"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
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
            "aws:SourceAccount" = "${var.cloudwatch_to_s3_kms_key_account_id}"
          }
        }
      }
    ]
  })
  tags = merge(
    var.tags,
    {
      Name = var.kms_key_name
    }
  )
}


# CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "main" {
  name              = var.log_group_name
  retention_in_days = var.retention_in_days
 
# KMS에서 받아와야 함
   kms_key_id = aws_kms_key.main.arn

  tags = merge(
    var.tags,
    {
      Name = var.log_group_name
      Type = "CloudWatchLogs"
    }
  )
  
  depends_on = [aws_kms_key.main]
}

# kinesis firehose 전송 IAM 역할
resource "aws_iam_role" "kinesis_firehose_role" {
  name = var.kinesis_firehose_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

# kinesis firehose 전송 IAM 역할 정책
resource "aws_iam_role_policy" "kinesis_firehose_role_policy" {
  name = var.kinesis_firehose_role_policy_name
  role = aws_iam_role.kinesis_firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:PutObject",
                "s3:GetBucketLocation",
                "s3:ListBucket",]
      Effect = "Allow"
      Resource = ["arn:aws:s3:::${var.bucket_name}/*",
                  "arn:aws:s3:::${var.bucket_name}"]
    },
    {
      Action = ["kms:Encrypt",
                "kms:Decrypt",
                "kms:GenerateDataKey",
                "kms:DescribeKey"]
      Effect = "Allow"
      Resource = aws_kms_key.main.arn
    }]
  })
}

# kinesis firehose 전송 설정
resource "aws_kinesis_firehose_delivery_stream" "main" {
    name = var.delivery_stream_name
    destination = "extended_s3"
    extended_s3_configuration {
      bucket_arn = aws_s3_bucket.main.arn
      role_arn = aws_iam_role.kinesis_firehose_role.arn
      kms_key_arn = aws_kms_key.main.arn
    }
  }


# Cloudwatch 로그 필터링 설정
resource "aws_cloudwatch_log_subscription_filter" "main" {
  name = var.log_subscription_filter_name
  log_group_name = aws_cloudwatch_log_group.main.name
  filter_pattern = var.filter_pattern
  # kinesis firehose 전송 IAM 역할 사용
  destination_arn = aws_kinesis_firehose_delivery_stream.main.arn
  role_arn = aws_iam_role.cloudwatch_to_s3_role.arn
}

resource "aws_iam_role" "cloudwatch_to_s3_role" {
  name = var.cloudwatch_to_s3_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "logs.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

# CloudWatch Logs가 Kinesis Firehose에 쓰기 위한 IAM 역할 정책
resource "aws_iam_role_policy" "cloudwatch_to_s3_role_policy" {
  name = var.cloudwatch_to_s3_role_policy_name
  role = aws_iam_role.cloudwatch_to_s3_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["firehose:PutRecord", "firehose:PutRecordBatch"]
      Effect   = "Allow"
      Resource = aws_kinesis_firehose_delivery_stream.main.arn
    },
    {
      Action = ["kms:Encrypt",
                "kms:Decrypt",
                "kms:GenerateDataKey",
                "kms:DescribeKey"]
      Effect = "Allow"
      Resource = aws_kms_key.main.arn
    }]
  })
}

# 로그 담을 s3 버킷 생성
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  tags = merge(
    var.tags,
    {
      Name = var.bucket_name
      Type = "S3"
    }
  )
}

# 퍼블릭 엑세스 차단 설정
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id
  block_public_acls = var.public_access_block
  block_public_policy = var.public_access_block
  ignore_public_acls = var.public_access_block
  restrict_public_buckets = var.public_access_block
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      #  aws:kms는 유료
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.main.id
    }
  }
}
