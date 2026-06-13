output "app_log_group_name" {
  description = "CloudWatch log group name for app tasks."
  value       = aws_cloudwatch_log_group.app.name
}

output "edge_log_group_name" {
  description = "CloudWatch log group name for edge proxy tasks."
  value       = aws_cloudwatch_log_group.edge.name
}
