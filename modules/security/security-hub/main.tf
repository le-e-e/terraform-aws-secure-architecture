resource "aws_securityhub_account" "security-hub" {
  tags = var.tags
}

resource "aws_securityhub_standards_subscription" "SH_sub_standards" {
  standards_arn = "arn:aws:securityhub:::standards/aws-foundational-security-best-practices/v/1.0.0"
  tags = var.tags
}

resource "aws_securityhub_standards_subscription" "SH_sub_cis" {
  standards_arn = "arn:aws:securityhub:::standards/cis-aws-foundations-benchmark/v/1.0.0"
  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "SH_log" {
  name = "SH_event_rule"
  description = "SH_event_rule"
  event_pattern = jsonencode({
    source = ["aws.securityhub"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "SH_log_target" {
  rule = aws_cloudwatch_event_rule.SH_log.name
  arn = aws_securityhub_account.security-hub.arn
  target_id = "security-hub"
}

