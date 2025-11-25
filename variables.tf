variable "project_name" {
  type        = string
  default     = "aws-eks-security-architecture-in-terraform"
}


variable "aws_region" {
  type        = string
  default     = "ap-northeast-2"
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
  default     = {}
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
  default     = "cloudwatch-to-s3-log-group"
}

variable "retention_in_days" {
  # CloudWatch 로그 보존 기간 일단위 (0은 무제한)
  type        = number
  default     = 7
}

variable "filter_pattern" {
  type        = string
  default     = ""
}

variable "delivery_stream_name" {
  type        = string
  default     = "cloudwatch-to-s3-delivery-stream"
}

variable "cloudwatch_to_s3_role_name" {
  type        = string
  default     = "cloudwatch-to-s3-role"
}

variable "cloudwatch_to_s3_role_policy_name" {
  type        = string
  default     = "cloudwatch-to-s3-role-policy"
}

variable "kinesis_firehose_role_name" {
  type        = string
  default     = "kinesis-firehose-role"
}

variable "kinesis_firehose_role_policy_name" {
  type        = string
  default     = "kinesis-firehose-role-policy"
}

variable "bucket_name" {
  type        = string
  default     = "cloudwatch-to-s3-bucket-use-firehose-withlee"
}

variable "public_access_block" {
  type        = bool
  default     = true
}

variable "log_subscription_filter_name" {
  type        = string
  default     = "cloudwatch-to-s3-log-subscription-filter"
}


variable "cloudwatch_to_s3_account_id" {
  type        = string
  default     = ""
}

variable "cloudtrail_bucket_kms_key_arn" {
  type        = string
  default     = ""
}

variable "cloudtrail_bucket_kms_key_account_id" {
  type        = string
  default     = ""
}

variable "cloudtrail_name" {
  type        = string
  default     = "cloudtrail-withlee"
}

variable "cloudtrail_bucket_name" {
  type        = string
  default     = "cloudtrail-s3-bucket-withlee"
}

variable "cloudtrail_s3_key_prefix" {
  type        = string
  default     = ""
}

variable "config_delivery_channel_s3_bucket_kms_key_account_id" {
  type        = string
  default     = ""
}

variable "config_delivery_channel_s3_bucket_name" {
  type        = string
  default     = "config-s3-bucket-withlee"
}

variable "guardduty_s3_bucket_name" {
  type        = string
  default     = "guardduty-s3-bucket-withlee"
}

variable "guardduty_s3_bucket_kms_key_account_id" {
  type        = string
  default     = ""
}

variable "guardduty_kms_key_account_id" {
  type        = string
  default     = ""
}

variable "bad-ec2-isol-security-group-name" {
  type        = string
  default     = "isolation-security-group"
}

variable "bad-ec2-isol-event-rule-name" {
  type        = string
  default     = "bad-ec2-isol-rule"
}

variable "bad-ec2-isol-iam-role-name" {
  type        = string
  default     = "bad-ec2-isol-lambda-role"
}