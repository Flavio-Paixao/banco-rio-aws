variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes e tags)"
  type        = string
}

variable "domain_name" {
  description = "Dominio ficticio do banco. A zona hospedada nunca seria delegada num registrador real"
  type        = string
}

variable "primary_alb_dns_name" {
  description = "DNS do ALB da regiao primaria"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Zone ID do ALB da regiao primaria (para o registro alias)"
  type        = string
}

variable "dr_alb_dns_name" {
  description = "DNS do ALB da regiao de DR"
  type        = string
}

variable "dr_alb_zone_id" {
  description = "Zone ID do ALB da regiao de DR (para o registro alias)"
  type        = string
}

variable "health_check_interval" {
  description = "Segundos entre verificacoes do health check (30 padrao; 10 e mais rapido e custa mais)"
  type        = number
  default     = 30

  validation {
    condition     = contains([10, 30], var.health_check_interval)
    error_message = "health_check_interval deve ser 10 ou 30."
  }
}

variable "health_check_failure_threshold" {
  description = "Falhas seguidas ate o Route 53 considerar a regiao primaria fora do ar"
  type        = number
  default     = 3
}
