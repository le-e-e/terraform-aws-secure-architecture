output "config_configuration_recorder_id" {
  value = aws_config_configuration_recorder.main.id
}

output "config_configuration_recorder_name" {
  value = aws_config_configuration_recorder.main.name
}

output "config_delivery_channel_id" {
  value = aws_config_delivery_channel.main.id
}

output "config_delivery_channel_name" {
  value = aws_config_delivery_channel.main.name
}

output "s3_bucket_id" {
  value = aws_s3_bucket.config.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.config.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.config.id
}

output "iam_role_id" {
  value = var.enable ? aws_iam_role.config[0].id : null
}

output "iam_role_arn" {
  value = var.enable ? aws_iam_role.config[0].arn : null
}

output "iam_role_name" {
  value = var.enable ? aws_iam_role.config[0].name : null
}

output "kms_key_id" {
  value = aws_kms_key.config.id
}

output "kms_key_arn" {
  value = aws_kms_key.config.arn
}
