variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

# ---------- regiao primaria ----------

variable "primary_private_subnet_ids" {
  description = "Subnets privadas da regiao primaria (2 AZs)"
  type        = list(string)
}

variable "primary_azs" {
  description = "AZs da regiao primaria: writer na 1a e reader na 2a"
  type        = list(string)
}

variable "primary_db_security_group_id" {
  description = "Security group do banco na regiao primaria"
  type        = string
}

variable "primary_kms_key_arn" {
  description = "Chave de dados (KMS) da regiao primaria"
  type        = string
}

# ---------- regiao de DR ----------

variable "dr_private_subnet_ids" {
  description = "Subnets privadas da regiao de DR (2 AZs)"
  type        = list(string)
}

variable "dr_db_security_group_id" {
  description = "Security group do banco na regiao de DR"
  type        = string
}

variable "dr_kms_key_arn" {
  description = "Replica da chave de dados (KMS) na regiao de DR"
  type        = string
}

# ---------- banco ----------

variable "db_name" {
  description = "Nome do banco de dados criado no cluster"
  type        = string
  default     = "bancorio"
}

variable "db_username" {
  description = "Usuario administrador (a SENHA e gerada pelo Terraform e guardada no Secrets Manager)"
  type        = string
  default     = "bancoadmin"
}

variable "instance_classes" {
  description = "Classes de instancia aceitas, em ordem de preferencia. Global Database exige classes otimizadas para memoria (db.r5 ou superior)"
  type        = list(string)
  default     = ["db.r6g.large", "db.r5.large"]
}

variable "engine_version" {
  description = "Versao do Aurora PostgreSQL (familia 15). Conferir com: aws rds describe-db-engine-versions --engine aurora-postgresql --region sa-east-1"
  type        = string
  default     = "15.19"

  validation {
    condition     = can(regex("^15\\.[0-9]+$", var.engine_version))
    error_message = "A versao precisa ser da familia 15 (ex.: 15.19), porque o parameter group do modulo e aurora-postgresql15."
  }
}

variable "backup_retention_days" {
  description = "Dias de retencao dos backups automaticos do Aurora"
  type        = number
  default     = 7
}
