variable "project_name" {
    type = string
    default = "sg-checker"
}

variable "tags" {
    type = map(string)
    default = {}
}

variable "event_rule_name" {
    type = string
    default = "sg-checker-rule"
}

variable "iam_role_name" {
    type = string
    default = "sg-checker-lambda-role"
}

variable "iam_policy_name" {
    type = string
    default = "sg-checker-lambda-policy"
}

variable "lambda_function_name" {
    type = string
    default = "sg-checker-lambda"
}

variable "lambda_handler" {
    type = string
    default = "sg_checker.lambda_handler"
}

variable "lambda_runtime" {
    type = string
    default = "python3.12"
}

variable "lambda_memory_size" {
    type = number
    default = 256
}

variable "lambda_timeout" {
    type = number
    default = 10
}

variable "schedule_expression" {
    type = string
    default = "cron(0 0 * * ? *)"
}

variable "auto_delete" {
    type = bool
    default = false
    description = "Enable automatic deletion of vulnerable security groups"
}

variable "delete_only_critical" {
    type = bool
    default = true
    description = "Only delete security groups with critical severity findings"
}

variable "target_tag_key" {
    type = string
    default = ""
    description = "Optional tag key to filter security groups to check"
}

variable "target_tag_value" {
    type = string
    default = ""
    description = "Optional tag value to filter security groups to check"
}

variable "exception_tag_key" {
    type = string
    default = "SGCheckerException"
    description = "Tag key to mark security groups as exceptions (e.g., bastion hosts). Groups with this tag will be excluded from checks."
}