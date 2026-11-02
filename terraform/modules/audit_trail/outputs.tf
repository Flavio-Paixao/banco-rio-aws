output "audit_bucket_id" {
  description = "Nome do bucket de auditoria"
  value       = aws_s3_bucket.audit.id
}

output "audit_bucket_arn" {
  description = "ARN do bucket de auditoria"
  value       = aws_s3_bucket.audit.arn
}

output "trail_arn" {
  description = "ARN da trilha do CloudTrail"
  value       = aws_cloudtrail.main.arn
}
