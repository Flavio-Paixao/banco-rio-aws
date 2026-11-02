output "alb_dns_name" {
  description = "DNS do ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID do ALB (usado nos registros alias do Route 53)"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN do ALB"
  value       = aws_lb.main.arn
}

output "certificate_arn" {
  description = "ARN do certificado ACM"
  value       = aws_acm_certificate.main.arn
}

output "web_acl_arn" {
  description = "ARN do WAF"
  value       = aws_wafv2_web_acl.main.arn
}

output "alb_arn_suffix" {
  description = "Parte final do ARN do ALB (dimensao das metricas do CloudWatch)"
  value       = aws_lb.main.arn_suffix
}
