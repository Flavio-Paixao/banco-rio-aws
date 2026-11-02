output "primary_region" {
  description = "Regiao primaria"
  value       = var.primary_region
}

output "dr_region" {
  description = "Regiao de DR"
  value       = var.dr_region
}

output "primary_azs" {
  description = "AZs disponiveis na regiao primaria"
  value       = data.aws_availability_zones.primary.names
}

output "dr_azs" {
  description = "AZs disponiveis na regiao de DR"
  value       = data.aws_availability_zones.dr.names
}
