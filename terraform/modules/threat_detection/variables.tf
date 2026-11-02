variable "project_name" {
  description = "Nome do projeto (prefixo dos nomes)"
  type        = string
}

variable "enable_aggregation" {
  description = "Cria o agregador do Security Hub nesta regiao (so em UMA regiao)"
  type        = bool
  default     = false
}

variable "aggregation_regions" {
  description = "Regioes cujos achados do Security Hub sao agregados nesta regiao"
  type        = list(string)
  default     = []
}
