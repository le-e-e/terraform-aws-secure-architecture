output "lambda_function_arn" {
  value = aws_lambda_function.s3-public-block-lambda.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.s3-public-block-lambda.function_name
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.s3-public-block-rule.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.s3-public-block-rule.name
}

output "iam_role_arn" {
  value = aws_iam_role.s3-public-block-lambda-role.arn
}

output "iam_role_name" {
  value = aws_iam_role.s3-public-block-lambda-role.name
}

