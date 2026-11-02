variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "region_label" {
  description = "Rotulo da regiao nos nomes (por exemplo: primaria ou dr). Entra no nome da role, que e global"
  type        = string
}

variable "record_global_resources" {
  description = "Registrar recursos globais (como IAM). Ligue em UMA regiao so, para nao duplicar"
  type        = bool
  default     = false
}

variable "audit_bucket_id" {
  description = "Nome do bucket de auditoria que recebe os dados do Config"
  type        = string
}

variable "audit_bucket_arn" {
  description = "ARN do bucket de auditoria"
  type        = string
}

variable "logs_kms_key_arn" {
  description = "Chave KMS de logs (a do bucket de auditoria) que a role do Config precisa usar"
  type        = string
}
