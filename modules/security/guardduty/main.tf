resource "aws_guardduty_detector" "main" {
  count = var.enable ? 1 : 0
  enable = true
  finding_publishing_frequency = var.finding_publishing_frequency

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-guardduty"
      Type = "GuardDuty"
    }
  )
}