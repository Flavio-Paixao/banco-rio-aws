output "data_key_arn" {
  description = "ARN da chave de dados na regiao primaria"
  value       = aws_kms_key.data.arn
}

output "data_key_replica_arn" {
  description = "ARN da replica da chave de dados na regiao de DR"
  value       = aws_kms_replica_key.data.arn
}

output "logs_key_arn" {
  description = "ARN da chave de logs na regiao primaria"
  value       = aws_kms_key.logs.arn
}

output "logs_key_replica_arn" {
  description = "ARN da replica da chave de logs na regiao de DR"
  value       = aws_kms_replica_key.logs.arn
}
