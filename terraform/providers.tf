locals {
  # Tags aplicadas automaticamente em todo recurso que aceita tags, nas duas regioes
  default_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "Flavio"
    Repository  = "github.com/Flavio-Paixao/banco-rio-aws"
  }
}

# Provider padrao: regiao primaria (sa-east-1).
# Todo recurso sem "provider = ..." nasce aqui.
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = local.default_tags
  }
}

# Provider com apelido: regiao de DR (us-east-1).
# Recursos e modulos que devem nascer no DR usam: provider = aws.dr
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = local.default_tags
  }
}
