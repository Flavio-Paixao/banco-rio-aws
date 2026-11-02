variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "region_label" {
  description = "Rotulo da regiao nos nomes (primaria ou dr)"
  type        = string
}

variable "kms_key_arn" {
  description = "Chave KMS de dados da regiao (criptografa o cofre)"
  type        = string
}

variable "kms_key_arns" {
  description = "Chaves KMS que a role do backup pode usar (a da origem e a do destino da copia)"
  type        = list(string)
  default     = []
}

variable "create_plan" {
  description = "Cria role, plano e selecao de recursos. Na regiao de DR so existe o cofre que recebe as copias"
  type        = bool
  default     = false
}

variable "resource_arns" {
  description = "ARNs dos recursos protegidos pelo plano"
  type        = list(string)
  default     = []
}

variable "enable_copy" {
  description = "Copia cada ponto de recuperacao para outro cofre (outra regiao)"
  type        = bool
  default     = false
}

variable "copy_destination_vault_arn" {
  description = "ARN do cofre de destino da copia (usado so se enable_copy for true)"
  type        = string
  default     = ""
}

variable "schedule" {
  description = "Agenda do backup (cron do AWS Backup, em UTC)"
  type        = string
  default     = "cron(0 5 * * ? *)"
}

variable "retention_days" {
  description = "Dias de retencao de cada ponto de recuperacao (e da copia)"
  type        = number
  default     = 35
}

variable "lock_min_retention_days" {
  description = "Retencao minima que o Vault Lock exige de qualquer ponto de recuperacao"
  type        = number
  default     = 7
}

variable "lock_max_retention_days" {
  description = "Retencao maxima que o Vault Lock aceita"
  type        = number
  default     = 365
}
