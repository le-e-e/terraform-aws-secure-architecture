# CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "main" {
  name              = var.log_group_name
  retention_in_days = var.retention_in_days
 
 # KMS에서 받아와야 함
  kms_key_id = "arn:aws:kms:region:account:key/key-id"

  tags = merge(
    var.tags,
    {
      Name = var.log_group_name
      Type = "CloudWatchLogs"
    }
  )
}

resource "aws_kinesis_firehose_delivery_stream" "main" {
  name = var.delivery_stream_name
  destination = "s3"
  s3_configuration {
    bucket_arn = aws_s3_bucket.main.arn
    role_arn = aws_iam_role.main.arn
  }
}

resource "aws_iam_role" "main" {
  name = var.iam_role_name
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

resource "aws_iam_role_policy" "main" {
  name = var.iam_role_policy_name
  role = aws_iam_role.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "s3:*"
      Effect = "Allow"
      Resource = "arn:aws:s3:::${var.bucket_name}/*"
    }]
  })
}

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

variable "public_access_block" {
  type        = bool
  default     = true  
}

resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id
  events = var.s3_bucket_notification_events
  filter_prefix = var.s3_bucket_notification_filter_prefix
  filter_suffix = var.s3_bucket_notification_filter_suffix
}

