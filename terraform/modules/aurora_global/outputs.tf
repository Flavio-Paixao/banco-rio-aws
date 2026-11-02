output "global_cluster_id" {
  description = "ID do Global Database"
  value       = aws_rds_global_cluster.main.id
}

output "primary_cluster_arn" {
  description = "ARN do cluster primario"
  value       = aws_rds_cluster.primary.arn
}

output "primary_endpoint" {
  description = "Endpoint de escrita do cluster primario"
  value       = aws_rds_cluster.primary.endpoint
}

output "secondary_cluster_arn" {
  description = "ARN do cluster secundario (DR)"
  value       = aws_rds_cluster.secondary.arn
}

output "secondary_reader_endpoint" {
  description = "Endpoint de leitura do cluster secundario (DR)"
  value       = aws_rds_cluster.secondary.reader_endpoint
}

output "master_secret_arn" {
  description = "ARN do segredo com as credenciais do administrador (o valor nao e exposto)"
  value       = aws_secretsmanager_secret.master.arn
}

output "instance_class" {
  description = "Classe de instancia escolhida (primaria)"
  value       = data.aws_rds_orderable_db_instance.primary.instance_class
}
