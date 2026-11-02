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

# ==========================================
# Module: kms (chaves multi-region: primaria em sa-east-1, replicas em us-east-1)
# ==========================================

module "kms" {
  source = "./modules/kms"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project_name = var.project_name
}

# ==========================================
# Module: vpc_flow_logs (registro do trafego das VPCs, criptografado com a chave de logs)
# ==========================================

module "flow_logs_primary" {
  source = "./modules/vpc_flow_logs"

  project_name = var.project_name
  region_label = "primaria"
  vpc_id       = module.network_primary.vpc_id
  kms_key_arn  = module.kms.logs_key_arn
}

module "flow_logs_dr" {
  source = "./modules/vpc_flow_logs"

  providers = {
    aws = aws.dr
  }

  project_name = var.project_name
  region_label = "dr"
  vpc_id       = module.network_dr.vpc_id
  kms_key_arn  = module.kms.logs_key_replica_arn
}

# ==========================================
# Module: aurora_global (Aurora PostgreSQL Global Database: primario em sa-east-1, secundario em us-east-1)
# ==========================================

module "aurora_global" {
  source = "./modules/aurora_global"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project_name = var.project_name

  primary_private_subnet_ids   = module.network_primary.private_subnet_ids
  primary_azs                  = local.primary_azs
  primary_db_security_group_id = module.network_primary.db_security_group_id
  primary_kms_key_arn          = module.kms.data_key_arn

  dr_private_subnet_ids   = module.network_dr.private_subnet_ids
  dr_db_security_group_id = module.network_dr.db_security_group_id
  dr_kms_key_arn          = module.kms.data_key_replica_arn
}

# ==========================================
# Module: s3_replicated (bucket de dados em sa-east-1 com replicacao para us-east-1)
# ==========================================

module "s3_data" {
  source = "./modules/s3_replicated"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project_name        = var.project_name
  primary_kms_key_arn = module.kms.data_key_arn
  dr_kms_key_arn      = module.kms.data_key_replica_arn
}

# ==========================================
# Module: edge (ALB + ACM + WAF, uma instancia por regiao)
# ==========================================

module "edge_primary" {
  source = "./modules/edge"

  project_name          = var.project_name
  region_label          = "primaria"
  public_subnet_ids     = module.network_primary.public_subnet_ids
  alb_security_group_id = module.network_primary.alb_security_group_id
  domain_name           = var.domain_name
  logs_kms_key_arn      = module.kms.logs_key_arn
}

module "edge_dr" {
  source = "./modules/edge"

  providers = {
    aws = aws.dr
  }

  project_name          = var.project_name
  region_label          = "dr"
  public_subnet_ids     = module.network_dr.public_subnet_ids
  alb_security_group_id = module.network_dr.alb_security_group_id
  domain_name           = var.domain_name
  logs_kms_key_arn      = module.kms.logs_key_replica_arn
}

# ==========================================
# Module: dns (Route 53: zona, health check e registros de failover)
# ==========================================

module "dns" {
  source = "./modules/dns"

  project_name = var.project_name
  domain_name  = var.domain_name

  primary_alb_dns_name = module.edge_primary.alb_dns_name
  primary_alb_zone_id  = module.edge_primary.alb_zone_id
  dr_alb_dns_name      = module.edge_dr.alb_dns_name
  dr_alb_zone_id       = module.edge_dr.alb_zone_id
}

# ==========================================
# Module: audit_trail (bucket de auditoria e CloudTrail multi-regiao)
# ==========================================

module "audit_trail" {
  source = "./modules/audit_trail"

  project_name     = var.project_name
  logs_kms_key_arn = module.kms.logs_key_arn
  data_bucket_arns = [module.s3_data.source_bucket_arn, module.s3_data.destination_bucket_arn]
}

# ==========================================
# Module: config_recorder (AWS Config em cada regiao)
# ==========================================

module "config_primary" {
  source = "./modules/config_recorder"

  project_name            = var.project_name
  region_label            = "primaria"
  record_global_resources = true # recursos globais (IAM) ficam so numa regiao
  audit_bucket_id         = module.audit_trail.audit_bucket_id
  audit_bucket_arn        = module.audit_trail.audit_bucket_arn
  logs_kms_key_arn        = module.kms.logs_key_arn
}

module "config_dr" {
  source = "./modules/config_recorder"

  providers = {
    aws = aws.dr
  }

  project_name            = var.project_name
  region_label            = "dr"
  record_global_resources = false
  audit_bucket_id         = module.audit_trail.audit_bucket_id
  audit_bucket_arn        = module.audit_trail.audit_bucket_arn
  logs_kms_key_arn        = module.kms.logs_key_arn
}

# ==========================================
# Module: threat_detection (GuardDuty e Security Hub em cada regiao)
# ==========================================

module "threat_detection_dr" {
  source = "./modules/threat_detection"

  providers = {
    aws = aws.dr
  }

  project_name = var.project_name
}

module "threat_detection_primary" {
  source = "./modules/threat_detection"

  project_name        = var.project_name
  enable_aggregation  = true
  aggregation_regions = [var.dr_region]

  # O agregador so pode apontar para uma regiao onde o Security Hub ja esta ligado
  depends_on = [module.threat_detection_dr]
}
