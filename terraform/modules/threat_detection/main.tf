data "aws_region" "current" {}

# ==========================================
# GUARDDUTY (deteccao de ameacas)
# ==========================================
# Analisa CloudTrail, logs de DNS e Flow Logs sem precisar ligar nada alem do detector.

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name = "${var.project_name}-guardduty"
  }
}

# Protecoes extras que combinam com o banco: acessos a objetos do S3 e logins no Aurora
resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "rds_login" {
  detector_id = aws_guardduty_detector.main.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

# ==========================================
# SECURITY HUB (visao unica dos achados e checagens de boas praticas)
# ==========================================
# Depende do AWS Config gravando a configuracao dos recursos (modulo config_recorder).

resource "aws_securityhub_account" "main" {
  enable_default_standards = false
  auto_enable_controls     = true
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# Agrega os achados das outras regioes numa so (criado em uma regiao so)
resource "aws_securityhub_finding_aggregator" "main" {
  count = var.enable_aggregation ? 1 : 0

  linking_mode      = "SPECIFIED_REGIONS"
  specified_regions = var.aggregation_regions

  depends_on = [aws_securityhub_account.main]
}
