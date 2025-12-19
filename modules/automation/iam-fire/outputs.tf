output "lambda_function_arn" {
  value = aws_lambda_function.iam-fire-lambda.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.iam-fire-lambda.function_name
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.iam-fire-rule.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.iam-fire-rule.name
}

output "iam_role_arn" {
  value = aws_iam_role.iam-fire-lambda-role.arn
}

output "iam_role_name" {
  value = aws_iam_role.iam-fire-lambda-role.name
}

