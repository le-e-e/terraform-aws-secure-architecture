resource "aws_cloudwatch_event_rule" "s3-public-block-rule" {
  name = "s3-public-block-rule"
  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["s3.amazonaws.com"],
      "eventName": [
        "CreateBucket",
        "PutBucketAcl",
        "PutBucketPolicy",
        "PutBucketPublicAccessBlock"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "s3-public-block-target" {
  rule      = aws_cloudwatch_event_rule.s3-public-block-rule.name
  arn       = aws_lambda_function.s3-public-block-lambda.arn
  target_id = "lambda"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3-public-block-lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3-public-block-rule.arn
}

resource "aws_iam_role" "s3-public-block-lambda-role" {
  name = "s3-public-block-lambda-role"
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

resource "aws_iam_role_policy" "s3-public-block-lambda-policy" {
  name = "s3-public-block-lambda-policy"
  role = aws_iam_role.s3-public-block-lambda-role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
  {
    Action = [
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPublicAccessBlock"
    ],
    Effect = "Allow",
    Resource = ["arn:aws:s3:::*"]
  },
  {
    Action = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    Effect = "Allow",
    Resource = "arn:aws:logs:*:*:*"
  }
]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/s3_block.py"
  output_path = "${path.module}/s3_block.zip"
}

resource "aws_lambda_function" "s3-public-block-lambda" {
  function_name = "s3-public-block-lambda"
  role          = aws_iam_role.s3-public-block-lambda-role.arn
  handler       = "s3_block.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
}