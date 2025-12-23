output "lambda_function_arn" {
  value = aws_lambda_function.sg-checker-lambda.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.sg-checker-lambda.function_name
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.sg-checker-rule.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.sg-checker-rule.name
}

output "iam_role_arn" {
  value = aws_iam_role.sg-checker-role.arn
}

output "iam_role_name" {
  value = aws_iam_role.sg-checker-role.name
}

