resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "iam-access-analyzer"
  type = "ACCOUNT"
  tags = var.tags
}