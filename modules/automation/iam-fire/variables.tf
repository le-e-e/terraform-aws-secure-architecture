variable "project_name" {
  type = string
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "lambda_function_name" {
  type    = string
  default = "iam-fire-lambda"
}

variable "lambda_handler" {
  type    = string
  default = "iam_fire.lambda_handler"
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
  default = "iam-fire-rule"
}

variable "iam_role_name" {
  type    = string
  default = "iam-fire-lambda-role"
}

variable "iam_policy_name" {
  type    = string
  default = "iam-fire-lambda-policy"
}
