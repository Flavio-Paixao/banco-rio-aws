output "zone_id" {
  description = "ID da zona hospedada"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Servidores de nomes da zona (so teriam efeito com um dominio real)"
  value       = aws_route53_zone.main.name_servers
}

output "primary_health_check_id" {
  description = "ID do health check da regiao primaria"
  value       = aws_route53_health_check.primary.id
}
