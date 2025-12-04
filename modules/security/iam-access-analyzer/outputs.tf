output "analyzer_arn" {
  description = "IAM Access Analyzer ARN"
  value       = aws_accessanalyzer_analyzer.main.arn
}

output "analyzer_name" {
  description = "IAM Access Analyzer Name"
  value       = aws_accessanalyzer_analyzer.main.analyzer_name
}
