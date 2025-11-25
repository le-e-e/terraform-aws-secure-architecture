variable "project_name" {
  type = string
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  type = string
}

variable "lambda_function_name" {
  type    = string
  default = "bad-ec2-isol-lambda"
}

variable "lambda_handler" {
  type    = string
  default = "ec2_isol.lambda_handler"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "lambda_memory_size" {
  type    = number
  default = 256
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "event_rule_name" {
  type    = string
  default = "bad-ec2-isol-rule"
}

variable "iam_role_name" {
  type    = string
  default = "bad-ec2-isol-lambda-role"
}

variable "iam_policy_name" {
  type    = string
  default = "bad-ec2-isol-lambda-policy"
}

variable "security_group_name" {
  type    = string
  default = "bad-ec2-isol-sg"
}

