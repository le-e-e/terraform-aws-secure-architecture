output "cloudtrail_id" {
  value       = aws_cloudtrail.main.id
}

output "cloudtrail_arn" {
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_name" {
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_home_region" {
  value       = aws_cloudtrail.main.home_region
}

output "s3_bucket_id" {
  value       = aws_s3_bucket.cloudtrail_bucket.id
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.cloudtrail_bucket.arn
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.cloudtrail_bucket.id
}

output "kms_key_id" {
  value       = aws_kms_key.cloudtrail_bucket_kms_key.id
}

output "kms_key_arn" {
  value       = aws_kms_key.cloudtrail_bucket_kms_key.arn
}

