resource "aws_cloudwatch_event_rule" "go_to_deep" {
  name                = "${var.project_name}-go-to-deep"
  description         = "Schedule to move old Glacier backups to Deep Archive and delete 7+ year old backups"
  schedule_expression = "cron(0 3 * * ? *)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "go_to_deep" {
  rule      = aws_cloudwatch_event_rule.go_to_deep.name
  target_id = "${var.project_name}-go-to-deep"
  arn       = aws_lambda_function.go_to_deep.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_to_deep.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.go_to_deep.arn
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
      BACKUP_VAULT_NAME = var.backup_vault_name
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
          Sid    = "AllowBackupListAndCopy"
          Effect = "Allow"
          Action = [
            "backup:ListRecoveryPointsByBackupVault",
            "backup:StartCopyJob",
            "backup:DescribeCopyJob",
            "backup:GetRecoveryPointRestoreMetadata",
            "backup:DeleteRecoveryPoint"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "backup:BackupVaultName" = var.backup_vault_name
            }
          }
        }
      ]
    )
  })
}

