output "primary_region" {
  description = "Regiao primaria"
  value       = var.primary_region
}

output "dr_region" {
  description = "Regiao de DR"
  value       = var.dr_region
}

output "primary_azs" {
  description = "AZs usadas na regiao primaria"
  value       = local.primary_azs
}

output "dr_azs" {
  description = "AZs usadas na regiao de DR"
  value       = local.dr_azs
}

output "primary_vpc_id" {
  description = "ID da VPC na regiao primaria"
  value       = module.network_primary.vpc_id
}

output "dr_vpc_id" {
  description = "ID da VPC na regiao de DR"
  value       = module.network_dr.vpc_id
}

output "primary_private_subnet_ids" {
  description = "Subnets privadas da regiao primaria"
  value       = module.network_primary.private_subnet_ids
}

output "dr_private_subnet_ids" {
  description = "Subnets privadas da regiao de DR"
  value       = module.network_dr.private_subnet_ids
}

output "data_key_arn" {
  description = "Chave de dados multi-region (primaria, sa-east-1)"
  value       = module.kms.data_key_arn
}

output "data_key_replica_arn" {
  description = "Replica da chave de dados (DR, us-east-1)"
  value       = module.kms.data_key_replica_arn
}

output "logs_key_arn" {
  description = "Chave de logs multi-region (primaria, sa-east-1)"
  value       = module.kms.logs_key_arn
}

output "logs_key_replica_arn" {
  description = "Replica da chave de logs (DR, us-east-1)"
  value       = module.kms.logs_key_replica_arn
}

output "aurora_global_cluster_id" {
  description = "ID do Aurora Global Database"
  value       = module.aurora_global.global_cluster_id
}

output "aurora_instance_class" {
  description = "Classe de instancia escolhida para o Aurora"
  value       = module.aurora_global.instance_class
}

output "aurora_master_secret_arn" {
  description = "ARN do segredo com as credenciais do administrador (o valor nao e exposto)"
  value       = module.aurora_global.master_secret_arn
}

output "s3_source_bucket_arn" {
  description = "Bucket de dados na regiao primaria"
  value       = module.s3_data.source_bucket_arn
}

output "s3_destination_bucket_arn" {
  description = "Bucket de dados replicado na regiao de DR"
  value       = module.s3_data.destination_bucket_arn
}

output "alb_primary_dns_name" {
  description = "DNS do ALB na regiao primaria"
  value       = module.edge_primary.alb_dns_name
}

output "alb_dr_dns_name" {
  description = "DNS do ALB na regiao de DR"
  value       = module.edge_dr.alb_dns_name
}

output "dns_zone_id" {
  description = "ID da zona hospedada do Route 53"
  value       = module.dns.zone_id
}

output "dns_primary_health_check_id" {
  description = "ID do health check da regiao primaria"
  value       = module.dns.primary_health_check_id
}

output "audit_bucket_arn" {
  description = "Bucket de auditoria (CloudTrail e Config)"
  value       = module.audit_trail.audit_bucket_arn
}

output "cloudtrail_arn" {
  description = "Trilha multi-regiao do CloudTrail"
  value       = module.audit_trail.trail_arn
}
