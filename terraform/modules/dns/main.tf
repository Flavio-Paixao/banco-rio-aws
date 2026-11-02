# ==========================================
# ZONA HOSPEDADA
# ==========================================
# Route 53 e um servico global: nao depende da regiao do provider.
# Dominio ficticio: a zona nao e delegada em nenhum registrador, entao nenhum
# nome daqui responderia na internet de verdade.

resource "aws_route53_zone" "main" {
  #checkov:skip=CKV2_AWS_38:DNSSEC exige chave KMS assimetrica em us-east-1 e registro DS no registrador; so no desenho (DECISIONS D-17)
  #checkov:skip=CKV2_AWS_39:Query logging exige log group em us-east-1 e resource policy; so no desenho (DECISIONS D-17)
  name    = var.domain_name
  comment = "Zona do banco ficticio (projeto de estudo)"

  tags = {
    Name = "${var.project_name}-zona"
  }
}

# ==========================================
# HEALTH CHECK DA REGIAO PRIMARIA
# ==========================================
# O Route 53 testa o ALB de fora, a partir de varios pontos do mundo.
# Se falhar failure_threshold vezes seguidas, o registro PRIMARY deixa de ser usado.

resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  request_interval  = var.health_check_interval
  failure_threshold = var.health_check_failure_threshold
  enable_sni        = true

  tags = {
    Name = "${var.project_name}-health-check-primaria"
  }
}

# ==========================================
# REGISTROS DE FAILOVER
# ==========================================
# Mesmo nome, dois registros: o PRIMARY (sa-east-1) responde enquanto o health check estiver
# saudavel; se falhar, o Route 53 passa a responder com o SECONDARY (us-east-1).
# evaluate_target_health = false: o ALB nao tem alvos registrados (DECISIONS D-04), entao a
# decisao fica por conta do health check explicito acima.

resource "aws_route53_record" "primary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "primaria"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "secondary" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "dr"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.dr_alb_dns_name
    zone_id                = var.dr_alb_zone_id
    evaluate_target_health = false
  }
}
