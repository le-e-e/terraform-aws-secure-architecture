variable "backup_vault_name" {
  type = string
}

variable "backup_vault_arn" {
  description = "Backup Vault ARN (EventBridge 이벤트 필터링용)"
  type        = string
}

variable "project_name" {
  type = string
}

variable "aurora_cluster_id" {
  description = "Aurora 클러스터 ID (스냅샷 export용)"
  type        = string
}

variable "warm_storage_days" {
  description = "Warm storage 보관 기간 (일). 이 기간이 지나면 S3로 export"
  type        = number
  default     = 7  # AWS Backup에서 7일 warm storage만 유지
}

variable "tags" {
  type        = map(string)
  default     = {}
}

