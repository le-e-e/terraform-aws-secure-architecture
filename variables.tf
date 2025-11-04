variable "project_name" {
  type        = string
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "tags" {
  description = "태그"
  type        = map(string)
} 

variable "aws_region" {
  type        = string
  default     = "ap-northeast-2"
}

variable "enable" {
  description = "GuardDuty 활성화 여부"
  type        = bool
  default     = true
}

variable "finding_publishing_frequency" {
  description = "GuardDuty 탐지 주기"
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "log_group_name" {
  type        = string
}

variable "retention_in_days" {
  # CloudWatch 로그 보존 기간 일단위 (0은 무제한)
  type        = number
  default     = 7
}