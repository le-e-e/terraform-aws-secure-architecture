output "lambda_function_arn" {
  value = aws_lambda_function.bad-ec2-isol-lambda.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.bad-ec2-isol-lambda.function_name
}

output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.bad-ec2-isol-rule.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.bad-ec2-isol-rule.name
}

output "iam_role_arn" {
  value = aws_iam_role.bad-ec2-isol-lambda-role.arn
}

output "iam_role_name" {
  value = aws_iam_role.bad-ec2-isol-lambda-role.name
}

output "security_group_id" {
  value = aws_security_group.bad-ec2-isol-sg.id
}

output "security_group_arn" {
  value = aws_security_group.bad-ec2-isol-sg.arn
}

