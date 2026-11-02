output "dashboard_name" {
  description = "Nome do painel do CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
