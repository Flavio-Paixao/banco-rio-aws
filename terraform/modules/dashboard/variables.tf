variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "primary_region" {
  description = "Regiao primaria"
  type        = string
}

variable "dr_region" {
  description = "Regiao de DR"
  type        = string
}

variable "primary_alb_arn_suffix" {
  description = "Sufixo do ARN do ALB primario"
  type        = string
}

variable "dr_alb_arn_suffix" {
  description = "Sufixo do ARN do ALB de DR"
  type        = string
}

variable "aurora_secondary_cluster_id" {
  description = "Identificador do cluster Aurora secundario"
  type        = string
}

variable "health_check_id" {
  description = "ID do health check do Route 53"
  type        = string
}
