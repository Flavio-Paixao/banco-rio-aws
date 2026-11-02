variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "logs_kms_key_arn" {
  description = "Chave KMS de logs (regiao primaria) que criptografa o bucket, a trilha e o log group"
  type        = string
}

variable "data_bucket_arns" {
  description = "ARNs dos buckets de dados cujos acessos a objetos (data events) serao registrados"
  type        = list(string)
}

variable "log_retention_days" {
  description = "Dias de retencao do log group da trilha no CloudWatch"
  type        = number
  default     = 365
}

variable "audit_retention_days" {
  description = "Dias ate apagar os logs de auditoria do bucket (2555 = 7 anos; escolha de projeto, nao exigencia legal)"
  type        = number
  default     = 2555
}
