resource "aws_cloudwatch_event_rule" "ec2-monitoring-repair-rule" {
  name = "ec2-monitoring-repair-rule"
  event_pattern = jsoncode({
    "source": ["aws.ec2"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["ec2.amazonaws.com"],
      "eventName": ["UnmonitorInstances"],
      "responseElements": {
        "instancesSet": {
          "item": {
            "monitoring": {
              "state": ["disabled"]
            }
          }
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "ec2-monitoring-repair-target" {
  rule      = aws_cloudwatch_event_rule.ec2-monitoring-repair-rule.name
  arn       = aws_lambda_function.monitoring-repair-lambda.arn
  target_id = "lambda"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitoring-repair-lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2-monitoring-repair-rule.arn
}

resource "aws_iam_role" "monitoring-repair-lambda-role" {
  name = "monitoring-repair-lambda-role"
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

resource "aws_iam_role_policy" "monitoring-repair-lambda-policy" {
  name = "monitoring-repair-lambda-policy"
  role = aws_iam_role.monitoring-repair-lambda-role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*"
      },
      {
        "Effect": "Allow",
        "Action": "ec2:MonitorInstances",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring-repair-lambda-policy-attachment" {
  role       = aws_iam_role.monitoring-repair-lambda-role.id
  policy_arn = aws_iam_role_policy.monitoring-repair-lambda-policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/repair.py"
  output_path = "${path.module}/repair.zip"
}

resource "aws_lambda_function" "monitoring-repair-lambda" {
  function_name = "monitoring-repair-lambda"
  role          = aws_iam_role.monitoring-repair-lambda-role.arn
  handler       = "repair.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  depends_on = [aws_iam_role_policy_attachment.monitoring-repair-lambda-policy-attachment]

  # 메모리, 타임아웃 설정
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
}

