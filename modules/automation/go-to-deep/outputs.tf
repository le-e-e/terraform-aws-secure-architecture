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
  value = aws_cloudwatch_event_rule.go_to_deep_cleanup.arn
}

output "s3_bucket_name" {
  description = "Deep Archive 저장용 S3 버킷 이름"
  value       = aws_s3_bucket.backup_archive.id
}

output "s3_bucket_arn" {
  description = "Deep Archive 저장용 S3 버킷 ARN"
  value       = aws_s3_bucket.backup_archive.arn
}

output "aurora_export_role_arn" {
  description = "Aurora export를 위한 IAM Role ARN"
  value       = aws_iam_role.aurora_export_role.arn
}

