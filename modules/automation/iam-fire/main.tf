resource "aws_cloudwatch_event_rule" "iam-fire-rule" {
  name = var.event_rule_name
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {
      "type": [
        "Exfiltration:IAMUser/AnomalousBehavior",
        "Impact:IAMUser/AnomalousBehavior",
        "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS",
        "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "ima-fire-target" {
  rule = aws_cloudwatch_event_rule.iam-fire-rule.name
  arn = aws_lambda_function.iam-fire-lambda.arn
  target_id = "lambda"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id = "AllowExecutionFromEventBridge"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iam-fire-lambda.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.iam-fire-rule.arn
}

resource "aws_iam_role" "iam-fire-lambda-role" {
  name = var.iam_role_name
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
}

resource "aws_iam_role_policy" "iam-fire-lambda-policy" {
  name = var.iam_policy_name
  role = aws_iam_role.iam-fire-lambda-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/iam-fire-lambda*"
      },
      {
        Sid    = "AllowIAMUserRead"
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListAccessKeys"
        ]
        Resource = "arn:aws:iam::*:user/*"
      },
      {
        Sid    = "AllowIAMUserPolicyManagement"
        Effect = "Allow"
        Action = [
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:DetachUserPolicy"
        ]
        Resource = "arn:aws:iam::*:user/*"
      },
      {
        Sid    = "AllowAccessKeyDeletion"
        Effect = "Allow"
        Action = [
          "iam:DeleteAccessKey"
        ]
        Resource = "arn:aws:iam::*:user/*"
      }
    ]
  })
}

resource "aws_lambda_function" "iam-fire-lambda" {
  function_name = var.lambda_function_name
  role = aws_iam_role.iam-fire-lambda-role.arn
  memory_size = var.lambda_memory_size
  timeout = var.lambda_timeout
  handler = var.lambda_handler
  runtime = var.lambda_runtime
  filename = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "${path.module}/iam_fire.py"
  output_path = "${path.module}/iam_fire.zip"
}