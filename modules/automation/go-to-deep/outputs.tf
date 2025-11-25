output "lambda_function_name" {
  value = aws_lambda_function.go_to_deep.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.go_to_deep.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.go_to_deep.arn
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.go_to_deep.arn
}

