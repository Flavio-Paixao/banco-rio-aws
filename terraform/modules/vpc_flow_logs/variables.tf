variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "region_label" {
  description = "Rotulo da regiao nos nomes (por exemplo: primaria ou dr). Entra no nome da role, que e global"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC cujo trafego sera registrado"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN da chave KMS (da mesma regiao) que criptografa o log group"
  type        = string
}

variable "retention_in_days" {
  description = "Dias de retencao dos logs no CloudWatch"
  type        = number
  default     = 365
}
