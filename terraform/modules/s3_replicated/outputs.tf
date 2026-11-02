output "source_bucket_arn" {
  description = "ARN do bucket de origem (sa-east-1)"
  value       = aws_s3_bucket.source.arn
}

output "destination_bucket_arn" {
  description = "ARN do bucket de destino (us-east-1)"
  value       = aws_s3_bucket.destination.arn
}

output "replication_role_arn" {
  description = "ARN da role de replicacao"
  value       = aws_iam_role.replication.arn
}
