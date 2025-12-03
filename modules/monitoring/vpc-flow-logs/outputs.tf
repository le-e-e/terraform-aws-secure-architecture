output "flow_log_id" {
  value       = aws_flow_log.main.id
}

output "flow_log_arn" {
  value       = aws_flow_log.main.arn
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.vpc_flow_logs_bucket.id
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.vpc_flow_logs_bucket.arn
}

output "s3_bucket_domain_name" {
  value       = aws_s3_bucket.vpc_flow_logs_bucket.bucket_domain_name
}

output "kms_key_id" {
  value       = var.encryption_type == "kms" ? aws_kms_key.main[0].id : null
}

output "kms_key_arn" {
  value       = var.encryption_type == "kms" ? aws_kms_key.main[0].arn : null
}

output "kms_key_alias" {
  value       = var.encryption_type == "kms" ? aws_kms_alias.main[0].name : null
}

output "vpc_id" {
  value       = var.vpc_id
}
