output "security_hub_account_arn" {
  description = "Security Hub Account ARN"
  value       = aws_security_hub_account.security-hub.arn
}

output "security_hub_account_id" {
  description = "Security Hub Account ID"
  value       = aws_security_hub_account.security-hub.id
}

output "aws_foundational_standards_subscription_id" {
  description = "AWS Foundational Security Best Practices Standards Subscription ID"
  value       = aws_security_hub_standards_subscription.SH_sub_standards.id
}

output "cis_standards_subscription_id" {
  description = "CIS AWS Foundations Benchmark Standards Subscription ID"
  value       = aws_security_hub_standards_subscription.SH_sub_cis.id
}

output "event_rule_arn" {
  description = "Security Hub Event Rule ARN"
  value       = aws_cloudwatch_event_rule.SH_log.arn
}

output "event_rule_name" {
  description = "Security Hub Event Rule Name"
  value       = aws_cloudwatch_event_rule.SH_log.name
}

output "event_target_id" {
  description = "Security Hub Event Target ID"
  value       = aws_cloudwatch_event_target.SH_log_target.target_id
}

