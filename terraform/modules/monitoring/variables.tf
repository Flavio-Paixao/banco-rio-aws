variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "region_label" {
  description = "Rotulo da regiao nos nomes (primaria ou dr)"
  type        = string
}

variable "kms_key_arn" {
  description = "Chave KMS de logs da regiao (criptografa o topico SNS)"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Parte final do ARN do ALB (dimensao das metricas do CloudWatch)"
  type        = string
}

variable "alb_5xx_threshold" {
  description = "Erros 5xx do ALB em 5 minutos que disparam o alarme (limiar de estudo, nao medido)"
  type        = number
  default     = 5
}

variable "enable_replication_lag_alarm" {
  description = "Cria o alarme de atraso de replicacao do Aurora Global (so na regiao do cluster secundario)"
  type        = bool
  default     = false
}

variable "aurora_secondary_cluster_id" {
  description = "Identificador do cluster Aurora secundario (usado so se o alarme estiver ligado)"
  type        = string
  default     = ""
}

variable "replication_lag_threshold_ms" {
  description = "Atraso de replicacao (ms) que dispara o alarme. Limiar de alerta de estudo, nao e o RPO medido"
  type        = number
  default     = 5000
}

variable "enable_health_check_alarm" {
  description = "Cria o alarme do health check do Route 53 (as metricas so existem em us-east-1)"
  type        = bool
  default     = false
}

variable "health_check_id" {
  description = "ID do health check da regiao primaria (usado so se o alarme estiver ligado)"
  type        = string
  default     = ""
}
