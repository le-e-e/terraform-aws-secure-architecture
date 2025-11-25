resource "aws_cloudwatch_event_rule" "bad-ec2-isol-rule" {
  name = var.event_rule_name
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {
      "type": [
        "UnauthorizedAccess:EC2/TorRelay",
        "Backdoor:Runtime/C&CActivity.B!DNS",
        "Backdoor:EC2/DenialOfService.Tcp",
        "CryptoCurrency:Runtime/BitcoinTool.B!DNS",
        "PrivilegeEscalation:Runtime/CGroupsReleaseAgentModified",
        "Trojan:Runtime/DGADomainRequest.C!DNS",
        "Backdoor:EC2/DenialOfService.UnusualProtocol",
        "Trojan:EC2/DGADomainRequest.B",
        "CryptoCurrency:Runtime/BitcoinTool.B",
        "Trojan:EC2/DGADomainRequest.C!DNS",
        "UnauthorizedAccess:EC2/MetadataDNSRebind",
        "Execution:Runtime/ReverseShell",
        "Trojan:Runtime/DGADomainRequest.C!DNS",
        "CryptoCurrency:Runtime/BitcoinTool.B",
        "Trojan:Runtime/DriveBySourceTraffic!DNS"
      ]
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bad-ec2-isol-rule"
    }
  )
}

resource "aws_security_group" "bad-ec2-isol-sg" {
  name        = var.security_group_name
  description = "Security group for bad EC2 instances"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bad-ec2-isol-sg"
    }
  )
}
resource "aws_security_group_rule" "bad-ec2-isol-sg-rule" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bad-ec2-isol-sg.id
}


resource "aws_cloudwatch_event_target" "bad-ec2-isol-target" {
  rule      = aws_cloudwatch_event_rule.bad-ec2-isol-rule.name
  arn       = aws_lambda_function.bad-ec2-isol-lambda.arn
  target_id = "lambda"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bad-ec2-isol-lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bad-ec2-isol-rule.arn
}

resource "aws_iam_role" "bad-ec2-isol-lambda-role" {
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

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bad-ec2-isol-lambda-role"
    }
  )
}

resource "aws_iam_role_policy" "bad-ec2-isol-lambda-policy" {
  name = var.iam_policy_name
  role = aws_iam_role.bad-ec2-isol-lambda-role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowLambdaLogging",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Sid": "AllowEC2QuarantineActions",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:ModifyInstanceAttribute"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:security-group/*"
            ]
        },
        {
            "Sid": "AllowIAMProfileDisassociation",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeIamInstanceProfileAssociations",
                "iam:DisassociateIamInstanceProfile"
            ],
            "Resource": "*"
        }
    ]
})
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/ec2_isol.py"
  output_path = "${path.module}/ec2_isol.zip"
}

resource "aws_lambda_function" "bad-ec2-isol-lambda" {
  function_name = var.lambda_function_name
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role          = aws_iam_role.bad-ec2-isol-lambda-role.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  environment {
    variables = {
      QUARANTINE_SECURITY_GROUP_ID = aws_security_group.bad-ec2-isol-sg.id
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bad-ec2-isol-lambda"
    }
  )
}


    
