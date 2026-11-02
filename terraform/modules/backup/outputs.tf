output "vault_arn" {
  description = "ARN do cofre de backup"
  value       = aws_backup_vault.main.arn
}

output "vault_name" {
  description = "Nome do cofre de backup"
  value       = aws_backup_vault.main.name
}
