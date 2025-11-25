variable "name" {
  type        = string
}

variable "engine" {
  type        = string
}

variable "engine_version" {
  type        = string
}

variable "database_name" {
  type        = string
}

variable "master_username" {
  description = "null이면 자동 생성"
  type        = string
  default     = null
}

variable "master_password" {
  description = "null이면 자동 생성 후 Secrets Manager 저장"
  type        = string
  sensitive   = true
  default     = null
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "create_security_group" {
  type        = bool
  default     = true
}

variable "enable_auto_password" {
  type        = bool
  default     = true
}

variable "allowed_security_group_ids" {
  description = "접근 허용할 보안 그룹 ID 목록 (예: EKS 노드)"
  type        = list(string)
  default     = []
}

variable "backup_retention_period" {
  description = "자동백업 보관일"
  type        = number
  default     = 30
}

variable "preferred_backup_window" {
  description = "자동백업 시간"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "엔진 패치 시간"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "performance_insights_kms_key_id" {
  type        = string
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "create_security_group=true면 생성된 보안 그룹과 병합됨"
  type        = list(string)
  default     = []
}

variable "instance_class" {
  type        = string
}

variable "instance_count" {
  type        = number
  default     = 2
}

variable "tags" {
  type        = map(string)
  default     = {}
}

# AWS Backup 관련 변수
variable "backup_cold_storage_after" {
  description = "백업을 Glacier로 전환할 기간 (일). 0-30일: Backup Vault, 30일 이후: Glacier"
  type        = number
  default     = 30
}

variable "backup_delete_after" {
  description = "백업을 삭제할 기간 (일). 권장: 365일(1년), 1095일(3년), 2555일(7년)"
  type        = number
  default     = 1095  # 3년 (보안 모범 사례)
}