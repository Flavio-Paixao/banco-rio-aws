variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes dos recursos)"
  type        = string
  default     = "banco-rio"
}

variable "environment" {
  description = "Ambiente. Este case e um projeto de estudo, validado so com plan"
  type        = string
  default     = "estudo"
}

variable "primary_region" {
  description = "Regiao primaria (Sao Paulo)"
  type        = string
  default     = "sa-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.primary_region))
    error_message = "primary_region deve ter o formato de uma regiao AWS, por exemplo sa-east-1."
  }
}

variable "dr_region" {
  description = "Regiao de recuperacao de desastre (N. Virginia)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.dr_region))
    error_message = "dr_region deve ter o formato de uma regiao AWS, por exemplo us-east-1."
  }
}

variable "primary_vpc_cidr" {
  description = "CIDR da VPC na regiao primaria (/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dr_vpc_cidr" {
  description = "CIDR da VPC na regiao de DR (/16). Nao pode se sobrepor ao da primaria"
  type        = string
  default     = "10.1.0.0/16"
}

variable "domain_name" {
  description = "Dominio ficticio do banco. Usado nos certificados e, na fase 7, no DNS. Nao e um dominio real"
  type        = string
  default     = "banco-rio.example.com"
}
