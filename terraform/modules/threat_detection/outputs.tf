output "guardduty_detector_id" {
  description = "ID do detector do GuardDuty nesta regiao"
  value       = aws_guardduty_detector.main.id
}
