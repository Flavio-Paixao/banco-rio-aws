data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # nome curto => regra gerenciada da AWS
  managed_rules = {
    s3-public-read-prohibited = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    s3-ssl-requests-only      = "S3_BUCKET_SSL_REQUESTS_ONLY"
    rds-storage-encrypted     = "RDS_STORAGE_ENCRYPTED"
    cloudtrail-enabled        = "CLOUD_TRAIL_ENABLED"
  }
}

# ==========================================
# ROLE DO AWS CONFIG
# ==========================================
# IAM e global: o nome inclui o rotulo da regiao para nao colidir entre as duas instancias.

data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "ConfigAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.project_name}-config-${var.region_label}"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name = "${var.project_name}-config-${var.region_label}"
  }
}

# Politica gerenciada pela AWS: permite ao Config ler a configuracao dos recursos
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Entrega no bucket de auditoria (que e criptografado com a chave de logs)
data "aws_iam_policy_document" "deliver" {
  statement {
    sid       = "LerAclDoBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [var.audit_bucket_arn]
  }

  statement {
    sid       = "GravarNoBucket"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${var.audit_bucket_arn}/config/AWSLogs/${local.account_id}/Config/*"]

    condition {
      test     = "StringLike"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "UsarChaveDeLogs"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = [var.logs_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "deliver" {
  name   = "entregar-no-bucket-de-auditoria"
  role   = aws_iam_role.config.id
  policy = data.aws_iam_policy_document.deliver.json
}

# ==========================================
# GRAVADOR, CANAL DE ENTREGA E REGRAS
# ==========================================

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.region_label}"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.record_global_resources
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-${var.region_label}"
  s3_bucket_name = var.audit_bucket_id
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main, aws_iam_role_policy.deliver]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_config_rule" "managed" {
  for_each = local.managed_rules

  name = "${var.project_name}-${var.region_label}-${each.key}"

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
