output "log_group_name" {
  description = "Nome do log group dos Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
