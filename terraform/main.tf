# Consultas (data sources): provam que as credenciais funcionam nas duas regioes
# e fornecem as AZs usadas pela rede.

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "dr" {
  provider = aws.dr

  state = "available"
}

locals {
  # Duas AZs por regiao, para alta disponibilidade
  primary_azs = slice(data.aws_availability_zones.primary.names, 0, 2)
  dr_azs      = slice(data.aws_availability_zones.dr.names, 0, 2)
}

# ==========================================
# Module: network (mesmo modulo, chamado nas duas regioes)
# ==========================================

module "network_primary" {
  source = "./modules/network"

  project_name = var.project_name
  region_label = "primaria"
  vpc_cidr     = var.primary_vpc_cidr
  azs          = local.primary_azs
}

module "network_dr" {
  source = "./modules/network"

  # Faz o modulo inteiro nascer na regiao de DR (us-east-1)
  providers = {
    aws = aws.dr
  }

  project_name = var.project_name
  region_label = "dr"
  vpc_cidr     = var.dr_vpc_cidr
  azs          = local.dr_azs
}
