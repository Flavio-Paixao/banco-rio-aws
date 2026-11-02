variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "region_label" {
  description = "Rotulo da regiao nos nomes e tags (por exemplo: primaria ou dr)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC. Precisa ser um /16: as subnets sao /24 calculadas a partir dele"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr deve ser um CIDR valido com mascara /16, por exemplo 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Zonas de disponibilidade usadas (2, para alta disponibilidade)"
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "Use exatamente 2 AZs."
  }
}

variable "db_port" {
  description = "Porta do PostgreSQL"
  type        = number
  default     = 5432
}
