output "lambda_function_arn" {
  value       = aws_lambda_function.monitoring-repair-lambda.arn
}

output "lambda_function_name" {
  value       = aws_lambda_function.monitoring-repair-lambda.function_name
}

output "event_rule_arn" {
  value       = aws_cloudwatch_event_rule.ec2-monitoring-repair-rule.arn
}

output "event_rule_name" {
  value       = aws_cloudwatch_event_rule.ec2-monitoring-repair-rule.name
}

output "iam_role_arn" {
  value       = aws_iam_role.monitoring-repair-lambda-role.arn
}

output "iam_role_name" {
  value       = aws_iam_role.monitoring-repair-lambda-role.name
}
