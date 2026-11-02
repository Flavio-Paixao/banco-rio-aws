variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "region_label" {
  description = "Rotulo da regiao nos nomes (por exemplo: primaria ou dr)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets publicas onde o ALB fica (2 AZs)"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group do ALB"
  type        = string
}

variable "domain_name" {
  description = "Dominio do certificado. Neste case o dominio e ficticio e o certificado nunca seria validado num apply real"
  type        = string
}

variable "logs_kms_key_arn" {
  description = "Chave KMS de logs (da mesma regiao) que criptografa o log group do WAF"
  type        = string
}

variable "log_retention_days" {
  description = "Dias de retencao dos logs do WAF no CloudWatch"
  type        = number
  default     = 365
}

variable "rate_limit" {
  description = "Maximo de requisicoes por IP em 5 minutos antes do WAF bloquear"
  type        = number
  default     = 1000
}
