output "cluster_id" {
  value = aws_aurora_cluster.main.id
}

output "cluster_arn" {
  value = aws_aurora_cluster.main.arn
}

output "cluster_endpoint" {
  value = aws_aurora_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  value = aws_aurora_cluster.main.reader_endpoint
}

output "cluster_database_name" {
  value = aws_aurora_cluster.main.database_name
}

output "cluster_port" {
  value = aws_aurora_cluster.main.port
}

output "backup_vault_arn" {
  value = aws_backup_vault.aurora_backup.arn
}

output "backup_vault_name" {
  value = aws_backup_vault.aurora_backup.name
}

output "backup_plan_id" {
  value = aws_backup_plan.aurora_backup.id
}

output "security_group_id" {
  value = var.create_security_group ? aws_security_group.aurora[0].id : null
}

output "master_password_secret_arn" {
  description = "자동 생성된 경우만 반환"
  value       = var.enable_auto_password && var.master_password == null ? aws_secretsmanager_secret.master_password[0].arn : null
  sensitive   = true
}
