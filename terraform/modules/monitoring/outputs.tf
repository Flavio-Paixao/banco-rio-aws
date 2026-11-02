output "alerts_topic_arn" {
  description = "ARN do topico SNS de alertas da regiao"
  value       = aws_sns_topic.alerts.arn
}
