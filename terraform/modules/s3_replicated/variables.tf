variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "primary_kms_key_arn" {
  description = "Chave de dados (KMS) na regiao primaria, usada no bucket de origem"
  type        = string
}

variable "dr_kms_key_arn" {
  description = "Replica da chave de dados (KMS) na regiao de DR, usada no bucket de destino"
  type        = string
}

variable "noncurrent_glacier_days" {
  description = "Dias ate mover versoes antigas para o Glacier"
  type        = number
  default     = 90
}

variable "noncurrent_expiration_days" {
  description = "Dias ate apagar versoes antigas (2555 = 7 anos; escolha de projeto, nao exigencia legal)"
  type        = number
  default     = 2555
}
