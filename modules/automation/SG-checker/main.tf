resource "aws_cloudwatch_event_rule" "sg-checker-rule" {
    name = var.event_rule_name
    event_pattern = jsonencode({
        "source": ["aws.ec2"],
        "detail-type": ["AWS API Call via CloudTrail"],
        "detail": {
            "eventSource": ["ec2.amazonaws.com"],
            "eventName": [
                "CreateSecurityGroup",
                "AuthorizeSecurityGroupIngress",
                "AuthorizeSecurityGroupEgress",
                "ModifySecurityGroupRules",
                "UpdateSecurityGroupRuleDescriptionsIngress",
                "UpdateSecurityGroupRuleDescriptionsEgress"
            ]
        }
    })
    tags = merge(
        var.tags,
        {
            Name = "${var.project_name}-${var.event_rule_name}"
        }
    )
}

resource "aws_cloudwatch_event_target" "sg-checker-target" {
    rule = aws_cloudwatch_event_rule.sg-checker-rule.name
    arn = aws_lambda_function.sg-checker-lambda.arn
    target_id = "lambda"
}

resource "aws_lambda_permission" "permission-sg-checker" {
    statement_id = "AllowExecutionFromEventBridge"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.sg-checker-lambda.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.sg-checker-rule.arn
}

resource "aws_iam_role" "sg-checker-role" {
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
            Name = "${var.project_name}-${var.iam_role_name}"
        }
    )
}

resource "aws_iam_role_policy" "sg-checker-policy" {
    name = var.iam_policy_name
    role = aws_iam_role.sg-checker-role.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
            Effect = "Allow"
            Resource = "arn:aws:logs:*:*:*"
        },
        {
            Sid    = "AllowEC2SecurityGroupOperations"
            Effect = "Allow"
            Action = [
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupRules",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteSecurityGroup",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress"
            ]
            Resource = [
                "arn:aws:ec2:*:*:security-group/*",
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:network-interface/*"
            ]
        },
        {
            Sid    = "AllowRDSDescribe"
            Effect = "Allow"
            Action = [
                "rds:DescribeDBInstances",
                "rds:DescribeDBClusters"
            ]
            Resource = "*"
        },
        {
            Sid    = "AllowELBDescribe"
            Effect = "Allow"
            Action = [
                "elasticloadbalancing:DescribeLoadBalancers"
            ]
            Resource = "*"
        }
        ]
    })
}

resource "aws_lambda_function" "sg-checker-lambda" {
    function_name = var.lambda_function_name
    role = aws_iam_role.sg-checker-role.arn
    memory_size = var.lambda_memory_size
    timeout = var.lambda_timeout
    handler = var.lambda_handler
    runtime = var.lambda_runtime
    filename = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    
    environment {
        variables = {
            AUTO_DELETE = var.auto_delete ? "true" : "false"
            DELETE_ONLY_CRITICAL = var.delete_only_critical ? "true" : "false"
            TARGET_TAG_KEY = var.target_tag_key != "" ? var.target_tag_key : ""
            TARGET_TAG_VALUE = var.target_tag_value != "" ? var.target_tag_value : ""
            EXCEPTION_TAG_KEY = var.exception_tag_key != "" ? var.exception_tag_key : "SGCheckerException"
        }
    }
    
    tags = merge(
        var.tags,
        {
            Name = "${var.project_name}-${var.lambda_function_name}"
        }
    )
}

data "archive_file" "lambda_zip" {
    type = "zip"
    source_file = "${path.module}/sg_checker.py"
    output_path = "${path.module}/sg_checker.zip"
}