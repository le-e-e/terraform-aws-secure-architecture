# S3 버킷 생성 (Deep Archive 저장용)
resource "aws_s3_bucket" "backup_archive" {
  bucket = "${var.project_name}-backup-archive"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-backup-archive"
    }
  )
}

# S3 버킷 버전 관리 활성화
resource "aws_s3_bucket_versioning" "backup_archive" {
  bucket = aws_s3_bucket.backup_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "backup_archive" {
  bucket = aws_s3_bucket.backup_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "backup_archive" {
  bucket = aws_s3_bucket.backup_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}

# S3 라이프사이클 규칙: 즉시 Glacier로 전환, 1년 후 Deep Archive로 전환
resource "aws_s3_bucket_lifecycle_configuration" "backup_archive" {
  bucket = aws_s3_bucket.backup_archive.id

  rule {
    id     = "transition-to-glacier-then-deep-archive"
    status = "Enabled"

    # 즉시 Glacier로 전환 (비용 절감)
    transition {
      days          = 0
      storage_class = "GLACIER"
    }

    # 1년 후 Deep Archive로 전환
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# AWS Backup 완료 이벤트 감지 (백업 완료 즉시 실행)
resource "aws_cloudwatch_event_rule" "backup_completed" {
  name        = "${var.project_name}-backup-completed"
  description = "Trigger Lambda when AWS Backup job completes"

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Backup Job State Change"]
    detail = {
      state = ["COMPLETED"]
      backupVaultArn = [var.backup_vault_arn]
    }
  })

  tags = var.tags
}

# 7일 이상 된 백업 정리용 스케줄 (기존 백업 정리)
resource "aws_cloudwatch_event_rule" "go_to_deep_cleanup" {
  name                = "${var.project_name}-go-to-deep-cleanup"
  description         = "Schedule to clean up old backups (7+ years) and manage lifecycle"
  schedule_expression = "cron(0 3 * * ? *)"

  tags = var.tags
}

# 백업 완료 이벤트 타겟
resource "aws_cloudwatch_event_target" "backup_completed" {
  rule      = aws_cloudwatch_event_rule.backup_completed.name
  target_id = "${var.project_name}-backup-completed"
  arn       = aws_lambda_function.go_to_deep.arn
}

# 정리 작업용 스케줄 타겟
resource "aws_cloudwatch_event_target" "go_to_deep_cleanup" {
  rule      = aws_cloudwatch_event_rule.go_to_deep_cleanup.name
  target_id = "${var.project_name}-go-to-deep-cleanup"
  arn       = aws_lambda_function.go_to_deep.arn
}

resource "aws_lambda_permission" "allow_eventbridge_backup_completed" {
  statement_id  = "AllowExecutionFromEventBridgeBackupCompleted"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_to_deep.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_completed.arn
}

resource "aws_lambda_permission" "allow_eventbridge_cleanup" {
  statement_id  = "AllowExecutionFromEventBridgeCleanup"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_to_deep.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.go_to_deep_cleanup.arn
}

# CloudWatch Log Group 생성 (명시적 생성)
resource "aws_cloudwatch_log_group" "go_to_deep" {
  name              = "/aws/lambda/${var.project_name}-go-to-deep"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_lambda_function" "go_to_deep" {
  function_name    = "${var.project_name}-go-to-deep"
  filename         = data.archive_file.go_to_deep.output_path
  source_code_hash = data.archive_file.go_to_deep.output_base64sha256
  handler          = "go_to_deep.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.go_to_deep.arn
  timeout          = 300  # 5분 (백업 목록이 많을 수 있음)
  memory_size      = 256

  environment {
    variables = {
      BACKUP_VAULT_NAME     = var.backup_vault_name
      AURORA_CLUSTER_ID     = var.aurora_cluster_id
      S3_BUCKET_NAME        = aws_s3_bucket.backup_archive.id
      WARM_STORAGE_DAYS     = var.warm_storage_days
      AURORA_EXPORT_ROLE_ARN = aws_iam_role.aurora_export_role.arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-go-to-deep"
    }
  )
}

data "archive_file" "go_to_deep" {
  type = "zip"
  source_file = "${path.module}/go_to_deep.py"
  output_path = "${path.module}/go_to_deep.zip"
}

resource "aws_iam_role" "go_to_deep" {
  name = "${var.project_name}-go-to-deep-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "go_to_deep" {
  name = "${var.project_name}-go-to-deep-policy"
  role = aws_iam_role.go_to_deep.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowLambdaLogging"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-go-to-deep*"
        },
        {
          Sid    = "AllowBackupListAndDelete"
          Effect = "Allow"
          Action = [
            "backup:ListRecoveryPointsByBackupVault",
            "backup:GetRecoveryPointRestoreMetadata",
            "backup:DeleteRecoveryPoint",
            "backup:DescribeRecoveryPoint"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "backup:BackupVaultName" = var.backup_vault_name
            }
          }
        },
        {
          Sid    = "AllowAuroraSnapshotExport"
          Effect = "Allow"
          Action = [
            "rds:DescribeDBClusterSnapshots",
            "rds:DescribeDBClusters",
            "rds:StartExportTask"
          ]
          Resource = "*"
        },
        {
          Sid    = "AllowS3Write"
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.backup_archive.arn,
            "${aws_s3_bucket.backup_archive.arn}/*"
          ]
        },
        {
          Sid    = "AllowIAMPassRole"
          Effect = "Allow"
          Action = [
            "iam:PassRole"
          ]
          Resource = aws_iam_role.aurora_export_role.arn
        }
      ]
    )
  })
}

# Aurora Export를 위한 IAM Role (S3에 쓰기 권한)
resource "aws_iam_role" "aurora_export_role" {
  name = "${var.project_name}-aurora-export-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "export.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "aurora_export_role" {
  name = "${var.project_name}-aurora-export-policy"
  role = aws_iam_role.aurora_export_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject*",
          "s3:ListBucket",
          "s3:GetObject*",
          "s3:DeleteObject*",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.backup_archive.arn,
          "${aws_s3_bucket.backup_archive.arn}/*"
        ]
      }
    ]
  })
}

